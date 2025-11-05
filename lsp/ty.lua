local lsputils = require 'functions.lsp'
local path = vim.fs.joinpath(vim.fn.expand("$DEV"), "cont", "ruff", "target", "release", "ty")
local projects = { "finitum", "provider", "collector" }

return {
  cmd = { path, "server" },
  filetypes = { "python" },
  root_dir = lsputils.root_dir(
    { 'pyproject.toml', 'ty.toml', '.git', '.gitignore', '.editorconfig' }, {
      projects = projects
    }
  ),
  settings = {
    ty = {
      experimental = {
        auto_import = true,
        rename = true
      }
    }
  }
}
