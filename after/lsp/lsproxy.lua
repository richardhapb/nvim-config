local path = vim.fs.joinpath(vim.fn.expand("$HOME"), "proj", "lsproxy", "target", "debug", "lsproxy")

return {
  cmd = { path, '--stdio' },
  cmd_env = { RUST_LOG = "none,lsproxy=trace" },
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
