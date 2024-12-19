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
            "lua_ls",
            "docker_compose_language_service",
            "dockerls",
            "cssls",
            "eslint",
            "markdown_oxide",
            "dprint", -- JavaScript
            "html",
            "htmx",
            "ruff",
            "pyright",
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
