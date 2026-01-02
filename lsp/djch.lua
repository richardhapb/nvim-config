local lsputils = require 'functions.lsp'
local path = vim.fs.joinpath(vim.fn.expand("$HOME"), ".local", "bin", "djch")

if vim.fn.executable(path) == 0 then
  vim.lsp.enable("djch", false)
  return {}
end

return {
  cmd = { path, 'server' },
  cmd_env = { RUST_LOG = "tower_lsp=off,django_check=trace" },
  filetypes = { "python" },
  root_dir = lsputils.root_dir({ 'manage.py', 'pyproject.toml', '.git' })
}
