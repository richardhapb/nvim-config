return {
  init_options = { hostInfo = 'neovim' },
  cmd = { 'typescript-language-server', '--stdio' },
  filetypes = {
    'javascript',
    'javascriptreact',
    'javascript.jsx',
    'typescript',
    'typescriptreact',
    'typescript.tsx',
  },
  root_markers = { 'tsconfig.json', 'jsconfig.json', 'package.json', '.git' },
  root_dir = function(bufnr, on_dir)
    local markers = { 'package-lock.json', 'yarn.lock', 'pnpm-lock.yaml', 'bun.lockb', 'bun.lock', 'deno.lock',
      ".git", ".gitignore", ".editorconfig" }
    vim.fs.root(bufnr, markers)

    local project_root = vim.fs.root(bufnr, markers)
    if not project_root then
      return
    end

    on_dir(project_root)
  end,
  single_file_support = true,
}
