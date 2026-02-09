local lutils = require 'functions.lsp'

return {
  cmd = { 'ruby-lsp' },
  filetypes = { 'ruby', 'eruby' },
  root_dir = lutils.root_dir({ 'Gemfile', '.git' }),
  init_options = {
    formatter = 'auto',
    addonSettings = {
      ["Ruby LSP Rails"] = {
        enablePendingMigrationsPrompt = false,
      },
    },
  },
  single_file_support = true,
}
