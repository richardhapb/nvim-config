local lsp_utils = require 'functions.lsp'

return {
  'mrcjkb/rustaceanvim',
  dependencies = {
    "mfussenegger/nvim-dap"
  },
  version = '^5',
  lazy = false,
  config = function()
    vim.g.rustaceanvim = {
      server = {
        on_attach = function(_, bufnr)
          lsp_utils.set_keymaps(bufnr)
          vim.keymap.set('n', '<leader>e', require 'rustaceanvim.commands.diagnostic'.render_diagnostic_current_line,
            { desc = "Show diagnostics in a float window" })
          vim.keymap.set('n', '<leader>rt', "<CMD>RustLsp testables<CR>",
            { buffer = bufnr, noremap = true, desc = "Run cargo test" })
        end,
        default_settings = {
          ['rust-analyzer'] = {
            rustfmt = {
              extraArgs = { "--config", "max_width=110" }
            }
          },
        }
      },
    }
  end
}
