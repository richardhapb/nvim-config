local path = vim.fs.joinpath(vim.fn.expand("$DEV"), "cont", "ruff", "target", "release", "ty")
local projects = { "finitum" }

return {
  cmd = { path, "server" },
  filetypes = (function()
    local parent = vim.fn.getcwd()
    for _, project in ipairs(projects) do
      if parent:find(project .. "$") then
        return { "python" }
      end
    end
    return { "" }
  end)(),
  root_markers = { "pyproject.toml", ".git" },
  -- root_dir = vim.fn.getcwd(),
  settings = {
    ty = {
      experimental = {
        auto_import = true,
        rename = true
      }
    }
  }
}
