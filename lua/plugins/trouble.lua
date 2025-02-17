return {
   "folke/trouble.nvim",
   opts = {},
   cmd = "Trouble",
   keys = {
      {
         "<leader>tt",
         function()
            local trouble = require("trouble")
            trouble.toggle({ mode = "diagnostics", win = {type = "split", position = "bottom", size = {height = 15} }} )
         end,
         desc = "Diagnostics (Trouble)",
      },
      {
         "<leader>tb",
         function()
            local trouble = require("trouble")
            trouble.toggle({ filter = {buf = 0}, mode = "diagnostics", win = {type = "split", position = "bottom", size = {height = 15} }} )
         end,
         "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
         desc = "Buffer Diagnostics (Trouble)",
      },
      {
         "<leader>ts",
         function()
            local trouble = require("trouble")
            trouble.toggle({ mode = "symbols", win = {type = "split", position = "right", size = {width = 60} }} )
         end,
         desc = "Symbols (Trouble)",
      },
      {
         "<leader>tl",
         "<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
         desc = "LSP Definitions / references / ... (Trouble)",
      },
      {
         "<leader>tL",
         "<cmd>Trouble loclist toggle<cr>",
         desc = "Location List (Trouble)",
      },
      {
         "<leader>tQ",
         "<cmd>Trouble qflist toggle<cr>",
         desc = "Quickfix List (Trouble)",
      },
   },
}

