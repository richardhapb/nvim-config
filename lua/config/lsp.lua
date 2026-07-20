local lsp_utils = require 'functions.lsp'
local utils = require 'functions.utils'

pcall(vim.diagnostic.config, {
  underline = true,
  signs = true,
  float = {
    border = lsp_utils.border,
  },
  virtual_lines = false,
  update_in_insert = false,
  virtual_text = lsp_utils.virtual_text
})


-- Capabilities, make client capabilities is ran in neovim core
local capabilities = vim.lsp.protocol.make_client_capabilities()


local lsp_elements = {
  "lua_ls",
  'ruff',
  'cssls',
  "html",
  "ts_ls",
  "yamlls",
  "ty",
  "djls",
  "zls",
  "bashls",
  "jsonls",
  'gopls',
  "astro",
  "rust_analyzer",
  "tailwind",
  "ruby_lsp"
}

if not utils.is_raspberry_pi() then
  vim.list_extend(lsp_elements, {
    "clangd",
  })
end

for _, name in ipairs(lsp_elements) do
  if name:find("^zls") then
    -- ZLS snippets are annoying
    capabilities.textDocument.completion.completionItem.snippetSupport = false
  end
  local config = {
    on_attach = lsp_utils.on_attach,
    capabilities = capabilities,
  }

  vim.lsp.enable(name)
  vim.lsp.config(name, config)
end
