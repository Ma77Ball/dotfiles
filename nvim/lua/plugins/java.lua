-- Java tooling: LSP via jdtls (started per-buffer in ftplugin/java.lua),
-- plus debugging/tests which jdtls wires into nvim-dap itself.
return {
  {
    "mfussenegger/nvim-jdtls",
    ft = "java",
    dependencies = {
      "mfussenegger/nvim-dap",
    },
  },
}
