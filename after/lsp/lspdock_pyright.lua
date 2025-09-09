local lsp_utils = require 'functions.lsp'
local path = vim.fs.joinpath(vim.fn.expand("$HOME"), "proj", "lspdock", "target", "release", "lspdock")

return {
  cmd = { path, "--exec", "pyright-langserver", '--stdio' },
  cmd_env = { RUST_LOG = "none,lsdock=trace" },
  filetypes = { "python" },
  root_markers = {
    'pyproject.toml',
    'setup.py',
    'setup.cfg',
    'requirements.txt',
    'Pipfile',
    'pyrightconfig.json',
    '.git',
  },
  on_attach = lsp_utils.on_attach,
  settings = {
    python = {
      analysis = {
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = 'openFilesOnly',
      },
    },
  },
}
