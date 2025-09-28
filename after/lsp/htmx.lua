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
  root_dir = function(fname)
    return vim.fs.dirname(vim.fs.find('.git', { path = fname, upward = true })[1])
  end,
}
