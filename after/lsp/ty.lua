local path = vim.fs.joinpath(vim.fn.expand("$HOME"), "proj", "cont", "ruff", "target", "release", "ty")

return {
  cmd = { path, "server" },
  filetypes = { "python" },
  root_dir = vim.fs.root(0, { ".git/", "pyproject.toml" }),
}
