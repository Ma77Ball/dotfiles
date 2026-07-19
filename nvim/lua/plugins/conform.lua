-- conform.nvim: formatter dispatch. JSON via jq; format on save only.
-- No <leader>cf keybind here -- for json/jsonc/jsonl, <leader>cf opens a
-- read-only pretty-printed scratch view instead (see ftplugin/*.lua + lua/json_expand.lua).
return {
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    opts = {
      formatters = {
        -- JSONL: compact each object onto its own line (built-in jq uses `jq .`,
        -- which pretty-prints and would break the one-object-per-line format).
        jqlines = {
          command = "jq",
          args = { "-c", "." },
        },
      },
      formatters_by_ft = {
        json = { "jq" },
        jsonc = { "jq" },
        jsonl = { "jqlines" },
      },
      -- format on save
      format_on_save = { timeout_ms = 1000, lsp_format = "fallback" },
    },
    config = function(_, opts)
      require("conform").setup(opts)
    end,
  },
}
