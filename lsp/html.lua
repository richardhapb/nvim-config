return {
  cmd = { "bunx", 'vscode-html-language-server', '--stdio' },
  filetypes = { 'html', "htmldjango" },
  root_markers = { 'package.json', '.git' },
  single_file_support = true,
  settings = {},
  init_options = {
    provideFormatter = true,
    embeddedLanguages = { css = true, javascript = true },
    configurationSection = { 'html', 'css', 'javascript' },
  },
}
