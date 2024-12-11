return {
   {
      "williamboman/mason.nvim",
      config = function()
         require("mason").setup()
      end,
   },
   {
      "williamboman/mason-lspconfig.nvim",
      config = function()
         require("mason-lspconfig").setup({
            ensure_installed = {
            "docker_compose_language_service",
            "dockerls",
            "cssls",
				"markdown_oxide",
            "pylsp",
            "sqlls",
            "tailwindcss",
            "ts_ls",
            "vimls",
            "yamlls",
            },
         })
      end,
   },
   {
      "neovim/nvim-lspconfig",
   },
}
