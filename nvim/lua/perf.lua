-- perf.lua: one command, ":Perf", that shows the "compiled logic" of the
-- current file dispatched on filetype.
--
--   :Perf            filetype-aware view of the compiled output:
--                      cpp/c   -> local asm dump (g++/gcc -S -O2 -masm=intel),
--                                 the offline Godbolt view (uses your flags)
--                      python  -> CPython bytecode (python3 -m dis)
--                      java    -> JVM bytecode of the enclosing class if a
--                                 compiled .class is found under target/
--                      scala   -> not statically knowable (see :Perf!)
--   :Perf -O3 -march=native   extra flags are appended for the cpp/c path
--   :Perf!           JVM only: JMH-profile the @Benchmark method under the
--                    cursor with -prof perfasm -> the REAL JITed assembly.
--                    Runs sbt in a terminal split (needs a build; slow).
--
-- Why the split: C++/Python compile to a fixed artifact you can read straight
-- from the source, so those are instant and offline. Scala/Java "optimized
-- output" only exists once the JIT runs the code, so that path is a bang-guarded
-- benchmark run, not an editor-speed lookup.

local M = {}

-- Node types that count as an enclosing "function" per language. Used to name
-- the thing under the cursor (Python dis target, JMH benchmark regex).
local FUNC_NODES = {
  python = { function_definition = true },
  cpp    = { function_definition = true },
  c      = { function_definition = true },
  java   = { method_declaration = true, constructor_declaration = true },
  scala  = { function_definition = true },
}

-- Walk up from the node under the cursor to the nearest enclosing function and
-- return its declared name, or nil. Pure Treesitter, no LSP dependency.
local function enclosing_function_name()
  local ft = vim.bo.filetype
  local wanted = FUNC_NODES[ft]
  if not wanted then return nil end
  local ok, node = pcall(vim.treesitter.get_node)
  if not ok or not node then return nil end
  while node do
    if wanted[node:type()] then
      -- The name is the first "name"-ish child (identifier). Field name is
      -- "name" across these grammars.
      local name_node = node:field("name")[1]
      if name_node then
        return vim.treesitter.get_node_text(name_node, 0)
      end
    end
    node = node:parent()
  end
  return nil
end

-- Open the given lines in a throwaway vertical split, read-only, syntax `ft`.
local function show_scratch(lines, ft, title)
  vim.cmd("vsplit")
  local buf = vim.api.nvim_create_buf(false, true) -- listed=false, scratch=true
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = ft
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false
  vim.bo[buf].swapfile = false
  if title then
    pcall(vim.api.nvim_buf_set_name, buf, title)
  end
  return buf
end

-- Run a shell command, capture stdout+stderr, return lines.
local function run(cmd)
  local out = vim.fn.systemlist(cmd .. " 2>&1")
  return out, vim.v.shell_error
end

-- Search upward from `start_dir` for a file named `marker`; return its dir.
local function find_up(start_dir, marker)
  local dir = start_dir
  while dir and dir ~= "/" do
    if vim.fn.filereadable(dir .. "/" .. marker) == 1 then
      return dir
    end
    dir = vim.fn.fnamemodify(dir, ":h")
  end
  return nil
end

-- cpp/c: dump optimized assembly with the local compiler. Intel syntax,
-- verbose-asm comments on, unwind/cfi tables off so it reads clean. Directive
-- lines are stripped to approximate Compiler Explorer's filtered view.
local function view_asm(ft, extra_flags)
  vim.cmd("write")
  local src = vim.fn.shellescape(vim.fn.expand("%:p"))
  local cc = (ft == "cpp") and "g++ -std=c++20" or "gcc -std=c17"
  local flags = "-O2 -S -masm=intel -fverbose-asm -fno-asynchronous-unwind-tables"
  if extra_flags and extra_flags ~= "" then
    flags = flags .. " " .. extra_flags
  end
  local cmd = cc .. " " .. flags .. " " .. src .. " -o -"
  local out, code = run(cmd)
  if code ~= 0 then
    show_scratch(out, "text", "perf: compile error")
    return
  end
  -- Drop pure-directive lines (first non-space token starts with "."), keep
  -- labels and instructions. Labels like `main:` don't start with a dot.
  local filtered = {}
  for _, line in ipairs(out) do
    local first = line:match("^%s*(%S)")
    if first ~= "." then
      filtered[#filtered + 1] = line
    end
  end
  show_scratch(filtered, "asm", "perf: " .. vim.fn.expand("%:t") .. " (asm)")
end

-- python: CPython bytecode for the whole file; jump to the enclosing function's
-- disassembly section if we can name it.
local function view_python()
  vim.cmd("write")
  local src = vim.fn.shellescape(vim.fn.expand("%:p"))
  local out, _ = run("python3 -m dis " .. src)
  show_scratch(out, "text", "perf: " .. vim.fn.expand("%:t") .. " (bytecode)")
  local fn = enclosing_function_name()
  if fn then
    pcall(vim.fn.search, "Disassembly of .*" .. fn .. ">:")
  end
end

-- java: best-effort JVM bytecode. Only works if the class is already compiled
-- under a target/ dir (we don't have the build classpath here). Otherwise point
-- the user at :Perf!.
local function view_java()
  local base = vim.fn.expand("%:t:r")
  local root = find_up(vim.fn.expand("%:p:h"), "build.sbt")
    or find_up(vim.fn.expand("%:p:h"), "pom.xml")
    or vim.fn.getcwd()
  local hits = vim.fn.globpath(root, "**/" .. base .. ".class", false, true)
  if #hits == 0 then
    show_scratch({
      "No compiled " .. base .. ".class found under " .. root,
      "",
      "JVM bytecode needs a build classpath this view doesn't have, and",
      "bytecode is not where JIT optimization happens anyway.",
      "",
      "Put the cursor in a @Benchmark method and run  :Perf!  to see the",
      "real JITed assembly via JMH -prof perfasm.",
    }, "text", "perf: no class")
    return
  end
  local out, _ = run("javap -c -p " .. vim.fn.shellescape(hits[1]))
  show_scratch(out, "java", "perf: " .. base .. " (bytecode)")
end

-- The bang path: run the enclosing JMH @Benchmark method with perfasm so you
-- see the actual optimized machine code the JIT produced. Terminal split so
-- output streams live; this is a real build+run, not an editor lookup.
local function view_jmh_perfasm()
  local method = enclosing_function_name()
  if not method then
    vim.notify("perf: put the cursor inside a @Benchmark method first", vim.log.levels.WARN)
    return
  end
  local root = find_up(vim.fn.expand("%:p:h"), "build.sbt")
  if not root then
    vim.notify("perf: no build.sbt found above this file", vim.log.levels.WARN)
    return
  end
  -- amber is the JMH-enabled subproject in this repo; the regex targets just
  -- the method under the cursor. -f1/-wi/-i keep the run short.
  local pattern = ".*" .. method .. ".*"
  local sbt = string.format(
    'sbt "amber/Jmh/run -prof perfasm -f1 -wi 3 -i 5 %s"',
    pattern
  )
  local cmd = string.format("cd %s && %s", vim.fn.shellescape(root), sbt)
  vim.cmd("botright split")
  vim.cmd("resize 20")
  vim.cmd("terminal " .. cmd)
  vim.cmd("startinsert")
end

function M.perf(opts)
  local ft = vim.bo.filetype
  if opts.bang then
    if ft == "scala" or ft == "java" then
      view_jmh_perfasm()
    else
      vim.notify("perf: :Perf! (JMH perfasm) is JVM-only; use :Perf for " .. ft, vim.log.levels.WARN)
    end
    return
  end
  if ft == "cpp" or ft == "c" then
    view_asm(ft, opts.args)
  elseif ft == "python" then
    view_python()
  elseif ft == "java" then
    view_java()
  elseif ft == "scala" then
    vim.notify(
      "perf: Scala's optimized output only exists at runtime. Put the cursor "
        .. "in a @Benchmark method and run :Perf! for JITed asm via perfasm.",
      vim.log.levels.INFO
    )
  else
    vim.notify("perf: no view for filetype '" .. ft .. "'", vim.log.levels.WARN)
  end
end

function M.setup()
  vim.api.nvim_create_user_command("Perf", function(o)
    M.perf(o)
  end, {
    bang = true,
    nargs = "*",
    desc = "Show compiled output for the current file (cpp/c asm, python bytecode, java bytecode; ! = JMH perfasm on JVM)",
  })
end

return M
