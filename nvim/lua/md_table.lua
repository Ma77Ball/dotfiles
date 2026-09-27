-- Render the markdown table under the cursor as a styled HTML page and open it
-- in Brave. Bound to <leader>o for markdown buffers (see ftplugin/markdown.lua).
-- Pure Lua parse (no pandoc): finds the contiguous block of `|...|` lines around
-- the cursor, converts it to an HTML <table>, writes a self-contained file to a
-- temp path, and launches brave-browser detached.
local M = {}

local BROWSER = "brave-browser"

-- True if buffer line `lnum` (1-indexed) looks like a table row: starts with an
-- optional-indent pipe.
local function is_row(lnum)
  local l = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1] or ""
  return l:match("^%s*|") ~= nil
end

-- Contiguous table block containing the cursor, or nil if the cursor is not on
-- a table.
local function table_range()
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local total = vim.api.nvim_buf_line_count(0)
  if not is_row(cur) then
    return nil
  end
  local top, bot = cur, cur
  while top > 1 and is_row(top - 1) do
    top = top - 1
  end
  while bot < total and is_row(bot + 1) do
    bot = bot + 1
  end
  return top, bot
end

-- Nearest markdown heading above `lnum`, used as the page title.
local function heading_above(lnum)
  for l = lnum - 1, 1, -1 do
    local h = (vim.api.nvim_buf_get_lines(0, l - 1, l, false)[1] or ""):match("^#+%s+(.+)")
    if h then
      return h
    end
  end
  return "Table"
end

local function esc_html(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- Minimal inline markdown -> HTML: bold, code, strikethrough. HTML-escaped first.
local function inline(s)
  s = esc_html(vim.trim(s))
  s = s:gsub("%*%*(.-)%*%*", "<strong>%1</strong>")
  s = s:gsub("`(.-)`", "<code>%1</code>")
  s = s:gsub("~~(.-)~~", "<del>%1</del>")
  return s
end

-- Split a `| a | b |` row into trimmed cell strings.
local function split_cells(line)
  local body = line:match("^%s*|?(.-)|?%s*$") or line
  local cells = {}
  for cell in (body .. "|"):gmatch("(.-)|") do
    table.insert(cells, cell)
  end
  return cells
end

-- A separator row is all dashes/colons/spaces per cell, e.g. |---|:--:|.
local function is_separator(line)
  local body = line:gsub("|", ""):gsub("%s", "")
  return body ~= "" and body:match("^[:%-]+$") ~= nil
end

-- Column alignments from the separator row: "left" | "center" | "right".
local function alignments(sep_line)
  local aligns = {}
  for _, c in ipairs(split_cells(sep_line)) do
    c = vim.trim(c)
    local l, r = c:sub(1, 1) == ":", c:sub(-1) == ":"
    aligns[#aligns + 1] = (l and r) and "center" or (r and "right") or (l and "left") or "left"
  end
  return aligns
end

-- Strip inline markdown markers to plain text (for the TSV clipboard payload).
local function plain(s)
  return (vim.trim(s):gsub("%*%*", ""):gsub("~~", ""):gsub("`", ""))
end

-- Build a tab-separated version of the table (header + body) for spreadsheet paste.
local function to_tsv(header, rows)
  local lines = {}
  local hdr = {}
  for _, h in ipairs(header) do
    hdr[#hdr + 1] = plain(h)
  end
  lines[#lines + 1] = table.concat(hdr, "\t")
  for _, row in ipairs(rows) do
    local cells = {}
    for i = 1, #header do
      cells[i] = plain(row[i] or "")
    end
    lines[#lines + 1] = table.concat(cells, "\t")
  end
  return table.concat(lines, "\n")
end

local function build_html(title, header, aligns, rows, md_raw)
  local out = {}
  local function w(s)
    out[#out + 1] = s
  end
  w("<!doctype html><html><head><meta charset='utf-8'>")
  w("<title>" .. esc_html(title) .. "</title><style>")
  w([[
:root { color-scheme: light dark; }
body { margin: 0; padding: 40px; background: #eef1f5;
       font: 15px/1.5 -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }
.wrap { max-width: max-content; margin: 0 auto; }
.bar { display: flex; align-items: center; gap: 10px; margin: 0 0 14px; }
h1 { font-size: 20px; margin: 0; color: #1b2430; font-weight: 700; flex: 1; }
button { font: 600 13px inherit; cursor: pointer; border: 1px solid #c5ccd6;
         background: #fff; color: #1b2a44; padding: 6px 12px; border-radius: 7px;
         transition: all .12s; }
button:hover { background: #f2f6ff; border-color: #1f6feb; }
button.ok { background: #1a7f4b; border-color: #0d5030; color: #fff; }
table { border-collapse: collapse; background: #fff; border-radius: 10px; overflow: hidden;
        box-shadow: 0 6px 24px rgba(20,30,50,.12); }
th, td { padding: 10px 16px; border-bottom: 1px solid #e6e9ee; white-space: nowrap; }
thead th { background: #1b2a44; color: #fff; font-weight: 600; text-align: left; }
tbody tr:nth-child(even) td { background: #f7f9fc; }
tbody tr:last-child td { border-bottom: none; }
tbody tr:hover td { background: #eef4ff; }
code { background: #eef1f5; padding: 1px 5px; border-radius: 4px;
       font: 13px "SF Mono", ui-monospace, Menlo, Consolas, monospace; }
strong { color: #0d3b66; }
del { color: #98a2b3; }
@media (prefers-color-scheme: dark) {
  body { background: #0f141b; }
  h1 { color: #e6edf3; }
  button { background: #161b22; color: #e6edf3; border-color: #30363d; }
  button:hover { background: #1b2430; border-color: #1f6feb; }
  table { background: #161b22; box-shadow: 0 6px 24px rgba(0,0,0,.5); }
  th, td { border-bottom-color: #232a33; }
  thead th { background: #1f6feb; }
  tbody tr:nth-child(even) td { background: #1b212a; }
  tbody tr:hover td { background: #223049; }
  code { background: #21262d; }
  strong { color: #79c0ff; }
}
]])
  w("</style></head><body><div class='wrap'>")
  w("<div class='bar'><h1>" .. esc_html(title) .. "</h1>")
  w("<button id='btn-md' onclick='cp(\"md\",this)'>Copy Markdown</button>")
  w("<button id='btn-tsv' onclick='cp(\"tsv\",this)'>Copy TSV</button>")
  w("<button id='btn-png' onclick='cpPng(this)'>Copy PNG</button></div>")
  w("<table><thead><tr>")
  for i, h in ipairs(header) do
    w(string.format("<th style='text-align:%s'>%s</th>", aligns[i] or "left", inline(h)))
  end
  w("</tr></thead><tbody>")
  for _, row in ipairs(rows) do
    w("<tr>")
    for i = 1, #header do
      w(string.format("<td style='text-align:%s'>%s</td>", aligns[i] or "left", inline(row[i] or "")))
    end
    w("</tr>")
  end
  w("</tbody></table></div>")

  -- json_encode produces a valid JS string literal, so all escaping is handled.
  local data_md = vim.fn.json_encode(md_raw)
  local data_tsv = vim.fn.json_encode(to_tsv(header, rows))
  w("<script>")
  w("var DATA={md:" .. data_md .. ",tsv:" .. data_tsv .. "};")
  w([[
function flash(btn){ var t=btn.textContent; btn.textContent='Copied!'; btn.classList.add('ok');
  setTimeout(function(){ btn.textContent=t; btn.classList.remove('ok'); },1200); }
function fallback(text,btn){ var ta=document.createElement('textarea'); ta.value=text;
  ta.style.position='fixed'; ta.style.top='-1000px'; document.body.appendChild(ta);
  ta.focus(); ta.select(); try{ document.execCommand('copy'); flash(btn); }catch(e){}
  document.body.removeChild(ta); }
function cp(kind,btn){ var text=DATA[kind];
  if(navigator.clipboard&&navigator.clipboard.writeText){
    navigator.clipboard.writeText(text).then(function(){flash(btn);},function(){fallback(text,btn);});
  } else { fallback(text,btn); } }

// Draw the table (from the TSV payload) onto a canvas so it can be copied or
// saved as a real image. Self-contained: no external rendering library.
function grid(){ return DATA.tsv.split('\n').map(function(r){ return r.split('\t'); }); }
function fontFor(head){ return (head?'600 ':'')+'28px -apple-system,"Segoe UI",Roboto,Arial,sans-serif'; }
function renderCanvas(){
  var rows=grid(), ncol=rows[0].length;
  var padX=32, rowH=88;
  var probe=document.createElement('canvas').getContext('2d');
  var colW=new Array(ncol).fill(0);
  rows.forEach(function(r,ri){ probe.font=fontFor(ri===0);
    r.forEach(function(c,ci){ var m=probe.measureText(c).width; if(m>colW[ci]) colW[ci]=m; }); });
  colW=colW.map(function(x){ return Math.ceil(x)+padX*2; });
  var totalW=colW.reduce(function(a,b){return a+b;},0), totalH=rowH*rows.length;
  var cvs=document.createElement('canvas'); cvs.width=totalW; cvs.height=totalH;
  var ctx=cvs.getContext('2d'); ctx.textBaseline='middle';
  ctx.fillStyle='#ffffff'; ctx.fillRect(0,0,totalW,totalH);
  var y=0;
  rows.forEach(function(r,ri){
    ctx.fillStyle = ri===0 ? '#1b2a44' : (ri%2===0 ? '#f7f9fc' : '#ffffff');
    ctx.fillRect(0,y,totalW,rowH);
    var x=0;
    r.forEach(function(c,ci){
      ctx.font=fontFor(ri===0); ctx.fillStyle = ri===0 ? '#ffffff' : '#1b2430';
      ctx.fillText(c, x+padX, y+rowH/2); x+=colW[ci];
    });
    ctx.strokeStyle='#e6e9ee'; ctx.lineWidth=2; ctx.beginPath();
    ctx.moveTo(0,y+rowH-1); ctx.lineTo(totalW,y+rowH-1); ctx.stroke();
    y+=rowH;
  });
  return cvs;
}
function savePng(blob,btn,label){ var a=document.createElement('a');
  a.href=URL.createObjectURL(blob); a.download='table.png';
  document.body.appendChild(a); a.click(); document.body.removeChild(a);
  var t=btn.textContent; btn.textContent=label||'Saved PNG'; btn.classList.add('ok');
  setTimeout(function(){ btn.textContent=t; btn.classList.remove('ok'); },1400); }
function cpPng(btn){ renderCanvas().toBlob(function(blob){
  if(navigator.clipboard && window.ClipboardItem){
    navigator.clipboard.write([new ClipboardItem({'image/png':blob})])
      .then(function(){flash(btn);}, function(){ savePng(blob,btn,'Saved PNG (copy blocked)'); });
  } else { savePng(blob,btn); } },'image/png'); }
]])
  w("</script></body></html>")
  return table.concat(out, "\n")
end

-- True if the cursor is currently on a markdown table (used by the unified
-- <leader>o dispatcher in md_open.lua to decide whether to render a table).
function M.on_table()
  return (table_range()) ~= nil
end

function M.open()
  local top, bot = table_range()
  if not top then
    vim.notify("md-table: cursor is not on a table", vim.log.levels.WARN)
    return
  end
  local lines = vim.api.nvim_buf_get_lines(0, top - 1, bot, false)

  local header, aligns, rows = nil, {}, {}
  for _, line in ipairs(lines) do
    if is_separator(line) then
      aligns = alignments(line)
    elseif not header then
      header = split_cells(line)
    else
      rows[#rows + 1] = split_cells(line)
    end
  end
  if not header then
    vim.notify("md-table: no header row found", vim.log.levels.WARN)
    return
  end

  local title = heading_above(top)
  local html = build_html(title, header, aligns, rows, table.concat(lines, "\n"))

  local path = vim.fn.tempname() .. ".html"
  local fd = io.open(path, "w")
  if not fd then
    vim.notify("md-table: could not write temp file", vim.log.levels.ERROR)
    return
  end
  fd:write(html)
  fd:close()

  if vim.fn.executable(BROWSER) == 0 then
    vim.notify("md-table: '" .. BROWSER .. "' not found on PATH", vim.log.levels.ERROR)
    return
  end
  vim.fn.jobstart({ BROWSER, "file://" .. path }, { detach = true })
  vim.notify(string.format("md-table: opened %d-row table in Brave", #rows))
end

-- Convenience: register <leader>o for the current (markdown) buffer.
function M.map()
  vim.keymap.set("n", "<leader>o", M.open, {
    buffer = true,
    desc = "Open markdown table under cursor in Brave",
  })
end

return M
