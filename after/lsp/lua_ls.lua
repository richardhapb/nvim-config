local root_files = {
  '.luarc.json',
  '.luarc.jsonc',
  '.luacheckrc',
  '.stylua.toml',
  'stylua.toml',
  'selene.toml',
  'selene.yml',
  '.git',
}

return {
  cmd = { 'lua-language-server' },
  filetypes = { 'lua' },
  root_markers = root_files,
  single_file_support = true,
  log_level = vim.lsp.protocol.MessageType.Warning,
  settings = {
    Lua = {
      telemetry = { enable = false },
      runtime = {
        version = "Lua 5.1"
      },
      diagnostics = {
        globals = { "vim", 'require' },
      },
      workspace = {
        library = {
          unpack(vim.api.nvim_get_runtime_file("", true)),
          '${3rd}/luv/library',
          "${3rd}/busted/library",
          vim.fn.expand("$HOME/.hammerspoon/Spoons/EmmyLua.spoon/annotations"),
          vim.fn.expand("$VIMRUNTIME/lua"),
        },
        checkThirdParty = false
      },
    },
  }
}
