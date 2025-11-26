local lsputils = require 'functions.lsp'
local path = vim.fs.joinpath(vim.fn.expand("$DEV"), "cont", "django-language-server", "target", "release", "djls")

if vim.fn.executable(path) == 0 then
  vim.lsp.enable("djls", false)
  return {}
end

local projects = { "main", "development" }

return {
  cmd = { path, 'serve' },
  filetypes = { "htmldjango", "html", "python" },
  root_dir = lsputils.root_dir({ 'manage.py', 'pyproject.toml', '.git' }, { projects = projects })
}
