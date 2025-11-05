local lsputils = require 'functions.lsp'
local excluded_projects = { "pandas", "finitum", "provider", "collector" }

return {
  cmd = { "pyright-langserver", '--stdio' },
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
  }, { excluded_projects = excluded_projects }),
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
