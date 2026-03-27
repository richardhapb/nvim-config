local lsputils = require 'functions.lsp'
local excluded_projects = { "pandas" }

return {
  cmd = { "ty", "server" },
  filetypes = { "python" },
  root_dir = lsputils.root_dir(
    { 'pyproject.toml', 'ty.toml', '.git', '.gitignore', '.editorconfig' }, {
      excluded_projects = excluded_projects
    }
  ),
  init_options = {
    logFile = '/tmp/ty.log',
  },
  settings = {
    ty = {
      experimental = {
        autoImport = true,
        rename = true
      }
    }
  }
}
