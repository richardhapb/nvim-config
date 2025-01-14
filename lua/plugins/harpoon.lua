return {
   "ThePrimeagen/harpoon",
   branch = "harpoon2",
   dependencies = { "nvim-lua/plenary.nvim" },
   config = function()
      local harpoon = require("harpoon")
      harpoon:setup({})
      local keymap = vim.keymap.set

      keymap('n', '<leader>hh', function() harpoon.ui:toggle_quick_menu(harpoon:list()) end,
         { noremap = true, desc = "Toggle Harpoon" })
      keymap('n', '<leader>ha', function() harpoon:list():add() end, { noremap = true, desc = "Add Harpoon" })

      local numbers = { "1", "2", "3", "4", "5", "6", "7", "8", "9" }
      for i, number in ipairs(numbers) do
         keymap('n', '<leader>h' .. number, function() harpoon:list():select(i) end, { noremap = true, desc = "Harpoon " .. number })
      end

      keymap('n', '<C-p>', function() harpoon:list():prev() end, { noremap = true, desc = "Harpoon Prev" })
      keymap('n', '<C-n>', function() harpoon:list():next() end, { noremap = true, desc = "Harpoon Next" })
   end,
}

