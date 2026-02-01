local lsputils = require 'functions.lsp'

return {
  cmd = { "bunx", "tailwindcss-language-server", "--stdio" },

  filetypes = {
    "html",
    "htmldjango",
    "typescriptreact",
    "javascriptreact",
    "css",
    "scss",
    "sass",
  },
  root_dir = lsputils.root_dir(
    {
      "tailwind.config.js",
      "tailwind.config.cjs",
      "tailwind.config.mjs",
      "package.json",
      ".git"
    }
  ),

  root_markers = { 'package.json', '.git' },
  single_file_support = false,

  settings = {
    tailwindCSS = {
      validate = true,
      lint = {
        cssConflict = "warning",
        invalidApply = "error",
        invalidScreen = "error",
        invalidVariant = "error",
        invalidConfigPath = "error",
      },
      experimental = {
        classRegex = {
          "tw`([^`]*)",
          "tw\\(([^)]*)\\)",
          "className=\"([^\"]*)\"",
        },
      },
    },
  },
}
