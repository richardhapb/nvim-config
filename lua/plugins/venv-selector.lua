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
      require("venv-selector").setup {
         settings = {
            search = {
               work = {
                  command = "fd ^python$ -t l -t f -u ~/dev"
               },
               cwd = {
                  command = "fd ^python$ -t l -t f -u ."
               },
               dev = {
                  command = "fd ^python$ -t l -t f -u " .. vim.fn.expand("$DEV")
               },
            }
         }
      }
   end,
   keys = {
      { "<leader>vs", "<cmd>VenvSelect<cr>" },
      { "<leader>vv", function ()
         require("venv-selector").activate_from_path(vim.fn.stdpath('config') .. '/.venv/bin/python')
         print("Activated neovim venv")
      end },
   },
}

