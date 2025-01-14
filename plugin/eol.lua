local M = {}

function M.detect_fileformat()
   local fileformat

   local filepath = vim.fn.expand("%:p")
   local file = io.open(filepath, "r")

   if not file then
      return
   end

   local content = file:read("*a")
   file:close()

   if content:find("\r\n") then
      fileformat = "dos"
   elseif content:find("\n") then
      fileformat = "unix"
   elseif content:find("\r") then
      fileformat = "mac"
   end

   return fileformat
end

function M.setup()
   vim.api.nvim_create_autocmd(
      "BufWinEnter",
      {
         callback = function()
            local fileformat = M.detect_fileformat()
            if fileformat then
               local modified = vim.bo.modified
               vim.bo.fileformat = fileformat
               vim.bo.modified = modified
            end
         end
      })
end

M.setup()

return M

