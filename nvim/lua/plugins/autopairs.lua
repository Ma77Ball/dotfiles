-- nvim-autopairs: auto-close brackets/quotes and expand blocks on Enter.
-- Typing `{` inserts the matching `}`; pressing <CR> between `{}` opens an
-- indented block (cursor indented one level, `}` on its own line). Treesitter-
-- aware (check_ts), so pairing respects the language and skips strings/comments.
return {
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    dependencies = { "hrsh7th/nvim-cmp" },
    config = function()
      local npairs = require("nvim-autopairs")
      npairs.setup({
        check_ts = true,       -- use treesitter to decide when to pair (language-aware)
        map_cr = true,         -- <CR> inside a pair expands to an indented block
        fast_wrap = {},        -- Alt-e to wrap the next object in a pair
      })

      -- After confirming a function/method from nvim-cmp, add the `(` pair too.
      local ok, cmp = pcall(require, "cmp")
      if ok then
        local cmp_autopairs = require("nvim-autopairs.completion.cmp")
        cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
      end
    end,
  },
}
