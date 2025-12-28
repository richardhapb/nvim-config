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
  'pyright',
  'mypy', -- Used for some python Open source projects
  'cssls',
  "html",
  -- "ltex_plus",
  "ts_ls",
  "yamlls",
  "ty",
  -- "harper_ls",
  "djls",
  "pydj",
  "bashls",
  "jsonls",
  'gopls',
  "astro",
  "rust_analyzer",
}

if not utils.is_raspberry_pi() then
  vim.list_extend(lsp_elements, {
    "clangd",
  })
end

-------------------------------------------------------- Temporary ----------------------------------------------------------

vim.lsp.config("pyright", {
  handlers = {
    -- Override the default rename handler to remove the `annotationId` from edits.
    --
    -- Pyright is being non-compliant here by returning `annotationId` in the edits, but not
    -- populating the `changeAnnotations` field in the `WorkspaceEdit`. This causes Neovim to
    -- throw an error when applying the workspace edit.
    --
    -- See:
    -- - https://github.com/neovim/neovim/issues/34731
    -- - https://github.com/microsoft/pyright/issues/10671
    [vim.lsp.protocol.Methods.textDocument_rename] = function(err, result, ctx)
      if err then
        vim.notify('Pyright rename failed: ' .. err.message, vim.log.levels.ERROR)
        return
      end

      ---@cast result lsp.WorkspaceEdit
      for _, change in ipairs(result.documentChanges or {}) do
        for _, edit in ipairs(change.edits or {}) do
          if edit.annotationId then
            edit.annotationId = nil
          end
        end
      end

      local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
      vim.lsp.util.apply_workspace_edit(result, client.offset_encoding)
    end,
  }
})
------------------------------------------------------------------------------------------------------------------------

for _, name in ipairs(lsp_elements) do
  local config = {
    on_attach = lsp_utils.on_attach,
    capabilities = capabilities,
  }

  vim.lsp.enable(name)
  vim.lsp.config(name, config)
end
