return {
   "linux-cultist/venv-selector.nvim",
   dependencies = {
      "neovim/nvim-lspconfig",
      "mfussenegger/nvim-dap", "mfussenegger/nvim-dap-python", --optional
      { "nvim-telescope/telescope.nvim", branch = "0.1.x", dependencies = { "nvim-lua/plenary.nvim" } },
   },
   lazy = true,
   branch = "regexp",
   config = function()
      require("venv-selector").setup()
   end,
   keys = {
      { "<leader>vs", "<cmd>VenvSelect<cr>" },
      { "<leader>vv", function ()
         require("venv-selector").activate_from_path(vim.fn.stdpath('config') .. '/.venv/bin/python')
         print("Activated neovim venv")
      end },
   },
}

