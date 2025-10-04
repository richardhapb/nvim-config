local projects = { "pandas" }

return {
  cmd = { 'pylsp' },
  filetypes = (function()
    local parent = vim.fn.getcwd()
    for _, project in ipairs(projects) do
      if parent:find(project .. "$") then
        return { "python" }
      end
    end
    return { "" }
  end)(),
  root_markers = {
    'pyproject.toml',
    'setup.py',
    'setup.cfg',
    'requirements.txt',
    'Pipfile',
  },
  single_file_support = true,
}
