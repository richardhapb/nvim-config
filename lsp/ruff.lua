local path = vim.fs.joinpath(vim.fn.expand("$DEV"), "cont", "ruff", "target", "release", "ruff")

return {
  cmd = { path, 'server' },
  cmd_env = { RUST_LOG = "none,lspdock=trace" },
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
  single_file_support = true,
  trace = "messages",
  settings = {
    configurationPreference = 'filesystemFirst',
    exclude = { "node_modules", ".git", ".venv" },
    lineLength = 100,
    lint = {
      enabled = true,
      preview = true,
    },
    format = {
      enabled = true,
      preview = true,
    },
  }
}
