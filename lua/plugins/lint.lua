return {
   'mfussenegger/nvim-lint',
   dependencies = { "williamboman/mason.nvim" },
   config = function()
      local lint = require 'lint'
      lint.linters_by_ft = {
         python = { 'pylint' },
         lua = { 'luacheck' },
      }

      lint.linters.luacheck.args = { '--globals vim' }

      local binaries = { "cspell", "pylint", "luacheck" }

      for _, binary in ipairs(binaries) do
         if vim.fn.executable(binary) == 0 then
            vim.cmd("MasonInstall " .. binary)
         end
      end
   end

}

