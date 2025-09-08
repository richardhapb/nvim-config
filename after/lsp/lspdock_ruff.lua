local lsp_utils = require 'functions.lsp'
local path = vim.fs.joinpath(vim.fn.expand("$HOME"), "proj", "lspdock", "target", "release", "lspdock")

return {
  cmd = { path, "--exec", "ruff", 'server' },
  cmd_env = { RUST_LOG = "none,lsdock=trace" },
  filetypes = { 'python' },
  root_markers = {
    'pyproject.toml',
    'ruff.toml',
    '.ruff.toml',
    'setup.py',
    'setup.cfg',
    'requirements.txt',
    'Pipfile',
    'pyrightconfig.json',
    '.git',
  },
  on_attach = lsp_utils.on_attach,
  single_file_support = true,
  settings = {},
}
