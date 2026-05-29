-- Per-buffer JDTLS (Eclipse Java language server) startup.
-- Runs for every Java file. nvim-jdtls is loaded via `ft = "java"`.

local ok, jdtls = pcall(require, "jdtls")
if not ok then
  return
end

local mason = vim.fn.stdpath("data") .. "/mason"
local jdtls_pkg = mason .. "/packages/jdtls"

-- JDTLS itself must run on Java 21+. The system "java" here may be older (11 via
-- SDKMAN), so resolve an explicit JDK 21+ launcher. Falls back to PATH "java".
local function resolve_java21()
  local candidates = {
    "/usr/lib/jvm/java-21-openjdk/bin/java",
    "/usr/lib/jvm/java-25-openjdk/bin/java",
    vim.env.JDTLS_JAVA_HOME and (vim.env.JDTLS_JAVA_HOME .. "/bin/java") or nil,
  }
  -- Pick up any /usr/lib/jvm/java-2x* install as a last resort.
  for _, p in ipairs(vim.fn.glob("/usr/lib/jvm/java-2*/bin/java", true, true)) do
    table.insert(candidates, p)
  end
  for _, p in ipairs(candidates) do
    if p and vim.fn.executable(p) == 1 then
      return p
    end
  end
  return "java"
end
local java_runtime = resolve_java21()

-- Equinox launcher jar (version-agnostic glob).
local launcher = vim.fn.glob(jdtls_pkg .. "/plugins/org.eclipse.equinox.launcher_*.jar", true)

-- OS-specific config directory shipped with jdtls.
local config_dir = jdtls_pkg .. "/config_linux"

-- Resolve the project root and give each project its own workspace.
local root_markers = { "gradlew", "mvnw", "pom.xml", "build.gradle", "settings.gradle", ".git" }
local root_dir = jdtls.setup.find_root(root_markers)
if not root_dir or root_dir == "" then
  root_dir = vim.fn.getcwd()
end
local project_name = vim.fn.fnamemodify(root_dir, ":p:h:t")
local workspace_dir = vim.fn.stdpath("data") .. "/jdtls-workspace/" .. project_name

-- Debug + test bundles for nvim-dap (installed via mason-tool-installer).
local bundles = {}
local debug_jar = vim.fn.glob(
  mason .. "/packages/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar",
  true
)
if debug_jar ~= "" then
  table.insert(bundles, debug_jar)
end
vim.list_extend(
  bundles,
  vim.split(vim.fn.glob(mason .. "/packages/java-test/extension/server/*.jar", true), "\n")
)

-- Completion capabilities, matching the rest of the config (nvim-cmp).
local capabilities
local ok_cmp, cmp_lsp = pcall(require, "cmp_nvim_lsp")
if ok_cmp then
  capabilities = cmp_lsp.default_capabilities()
end

local config = {
  cmd = {
    java_runtime,
    "-Declipse.application=org.eclipse.jdt.ls.core.id1",
    "-Dosgi.bundles.defaultStartLevel=4",
    "-Declipse.product=org.eclipse.jdt.ls.core.product",
    "-Dlog.protocol=true",
    "-Dlog.level=ALL",
    "-Xmx1g",
    "--add-modules=ALL-SYSTEM",
    "--add-opens", "java.base/java.util=ALL-UNNAMED",
    "--add-opens", "java.base/java.lang=ALL-UNNAMED",
    "-jar", launcher,
    "-configuration", config_dir,
    "-data", workspace_dir,
  },
  root_dir = root_dir,
  capabilities = capabilities,
  settings = {
    java = {
      eclipse = { downloadSources = true },
      maven = { downloadSources = true },
      signatureHelp = { enabled = true },
      contentProvider = { preferred = "fernflower" },
      -- JDKs available for projects to target. The build tool / .java-version
      -- selects which one a project compiles against.
      configuration = {
        runtimes = {
          { name = "JavaSE-11", path = "/usr/lib/jvm/temurin-11-jdk" },
          { name = "JavaSE-21", path = "/usr/lib/jvm/java-21-openjdk" },
          { name = "JavaSE-25", path = "/usr/lib/jvm/java-25-openjdk" },
        },
      },
    },
  },
  init_options = {
    bundles = bundles,
  },
  on_attach = function(_, bufnr)
    -- Wire up nvim-dap: discover main classes and enable hot-code-replace.
    require("jdtls.dap").setup_dap_main_class_configs()
    jdtls.setup_dap({ hotcodereplace = "auto" })

    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end

    -- LSP navigation
    map("n", "gd", vim.lsp.buf.definition, "Go to definition")
    map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
    map("n", "gi", vim.lsp.buf.implementation, "Go to implementation")
    map("n", "gr", vim.lsp.buf.references, "References")
    map("n", "K", vim.lsp.buf.hover, "Hover docs")
    map("n", "<leader>cr", vim.lsp.buf.rename, "LSP: rename")
    map("n", "<leader>ca", vim.lsp.buf.code_action, "LSP: code action")
    map("n", "<leader>cf", function() vim.lsp.buf.format({ async = true }) end, "LSP: format")

    -- Java-specific refactors
    map("n", "<leader>jo", jdtls.organize_imports, "Java: organize imports")
    map("n", "<leader>jv", jdtls.extract_variable, "Java: extract variable")
    map("n", "<leader>jc", jdtls.extract_constant, "Java: extract constant")
    map("x", "<leader>jm", function() jdtls.extract_method(true) end, "Java: extract method")

    -- Test running (requires the java-test bundle)
    map("n", "<leader>tc", jdtls.test_class, "Java: test class")
    map("n", "<leader>tn", jdtls.test_nearest_method, "Java: test nearest method")
  end,
}

jdtls.start_or_attach(config)
