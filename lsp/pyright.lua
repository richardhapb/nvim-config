local path = vim.fs.joinpath(vim.fn.expand("$DEV"), "lspdock", "target", "release", "lspdock")
local lsputils = require 'functions.lsp'
local projects = { "nothing" }

return {
  cmd = { path, "--exec", "pyright-langserver", "--", '--stdio' },
  filetypes = { "python" },
  root_markers = {
  },
  root_dir = lsputils.root_dir({
    'pyproject.toml',
    'setup.py',
    'setup.cfg',
    'requirements.txt',
    'Pipfile',
    'pyrightconfig.json',
    '.git',
  }, { projects = projects }),
  settings = {
    python = {
      analysis = {
        typeCheckingMode = "strict",
        diagnosticMode = "workspace",
        diagnosticSeverityOverrides = {
          reportUnnecessaryTypeIgnoreComment = "warning",
          reportUnnecessaryCast = "warning",
        },
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
      },
    },
  },
}
