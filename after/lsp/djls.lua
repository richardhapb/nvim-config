if vim.fn.executable("djls") == 0 then
  vim.lsp.enable("djls", false)
  return {}
end

local projects = { "kitchen", "development" }

return {
  cmd = { 'djls', 'serve' },
  filetypes = (function()
    local parent = vim.fn.getcwd()
    for _, project in ipairs(projects) do
      if parent:find(project .. "$") then
        return { "htmldjango", "html", "python" }
      end
    end
    return { "" }
  end)(),
  root_markers = { 'manage.py', 'pyproject.toml', '.git' },
}
