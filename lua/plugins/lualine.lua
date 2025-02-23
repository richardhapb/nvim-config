local function relative_from_cwd()
   local path = vim.fn.expand('%:.')
  if path == '' then
    path = vim.fn.getcwd()
  end

  return path
end

local function lsp_clients()
   local clients = vim.lsp.get_clients {bufnr = 0}
   if not clients then
      return ''
   end

   local client_names = {}
   for _, client in pairs(clients) do
      table.insert(client_names, client.name)
   end

   return '[' .. table.concat(client_names, ', ') .. ']'
end

return {
   'nvim-lualine/lualine.nvim',
   dependencies = {
      { 'nvim-tree/nvim-web-devicons' },
      { "ofseed/copilot-status.nvim" }
   },
   config = function()
      require('lualine').setup {
         options = {
            theme = 'ayu',
            section_separators = { '', '' },
            component_separators = { '', '' },
         },
         sections = {
            lualine_a = { { relative_from_cwd, color = 'StatusLine' } },
            lualine_b = { 'branch' },
            lualine_c = { 'diff' },
            lualine_x = {
              lsp_clients, 'copilot', 'fileformat', 'filetype',
            },
            lualine_y = { 'progress', 'searchcount' },
            lualine_z = { 'location' },
         },
         inactive_sections = {
            lualine_a = { { relative_from_cwd, color = 'StatusLineNC' } },
            lualine_b = { 'branch' },
            lualine_c = {},
            lualine_x = {},
            lualine_y = {},
            lualine_z = {'diff'},
         },
         tabline = {},
         extensions = {'oil', 'fugitive'},
      }
   end,
}

