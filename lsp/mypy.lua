local lsputils = require 'functions.lsp'
local projects = { "pandas" }

return {
  cmd = { 'pylsp' },
  filetypes = { "python" },
  root_dir = lsputils.root_dir({
    'pyproject.toml',
    'setup.py',
    'setup.cfg',
    'requirements.txt',
    'Pipfile',
  }, { projects = projects }),
  single_file_support = true,
}
