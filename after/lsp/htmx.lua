return {
  cmd = { 'htmx-lsp' },
  filetypes = { -- filetypes copied and adjusted from tailwindcss-intellisense
    -- html
    'astro',
    'astro-markdown',
    'htmldjango',
    'html',
    'javascript',
    'javascriptreact',
    'typescript',
    'typescriptreact',
    'vue',
  },
  single_file_support = true,
  root_markers = { "package.json", ".git" }
}
