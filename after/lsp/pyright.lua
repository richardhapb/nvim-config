-- local path = vim.fs.joinpath(vim.fn.expand("$DEV"), "lspdock", "target", "release", "lspdock")
local excluded_projects = { "pandas", "finitum", "provider", "collector" }

return {
  cmd = { "pyright-langserver", '--stdio' },
  -- cmd = { path, "--exec", "pyright-langserver", '--stdio' },
  -- cmd_env = { RUST_LOG = "none,lspdock=trace" },
  filetypes = (function()
    local parent = vim.fn.getcwd()
    for _, project in ipairs(excluded_projects) do
      if parent:find(project .. "$") then
        return { "" }
      end
    end
    return { "python" }
  end)(),
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
