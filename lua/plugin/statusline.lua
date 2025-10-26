---@return string
local function lsp_status()
  local attached_clients = vim.lsp.get_clients({ bufnr = 0 })
  if #attached_clients == 0 then
    return ""
  end
  local names = vim.iter(attached_clients)
      :map(function(client)
        local name = client.name:gsub("language.server", "ls")
        return name
      end)
      :totable()
  return "[" .. table.concat(names, ", ") .. "]"
end

local function git_status()
  local obj = vim.system({ 'git', 'branch', '--show-current' }):wait()
  if not obj.stdout or obj.stdout == "" then
    return ""
  end

  return " " .. vim.fn.trim(obj.stdout)
end

function _G.statusline()
  return table.concat({
    "%f",
    "%h%w%m%r",
    git_status(),
    "%=",
    lsp_status(),
    "%-13a %-14(%l,%c%V%)",
    "%P",
  }, " ")
end

return {
  setup = function()
    vim.o.statusline = "%{%v:lua._G.statusline()%}"
  end
}
