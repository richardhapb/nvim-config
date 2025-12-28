local lsputils = require 'functions.lsp'
local path = vim.fs.joinpath(vim.fn.expand("$HOME"), ".local", "bin", "pydj")

if vim.fn.executable(path) == 0 then
  vim.lsp.enable("pydj", false)
  return {}
end

return {
  cmd = { path, 'server' },
  cmd_env = { RUST_LOG = "tower_lsp=none,pydj=trace" },
  filetypes = { "python" },
  root_dir = lsputils.root_dir({ 'manage.py', 'pyproject.toml', '.git' })
}
