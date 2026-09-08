local M = {}

--- Multicursor extmarks (namespace "nvim.multicursor") don't fire an event on
--- enable/disable, so poll on SafeState (idle checkpoint, not per-keystroke)
--- and drop unnamedplus while active so yanks/deletes at each cursor don't
--- clobber the system clipboard; restore it once the multicursor clears.
function M.setup_multicursor_clipboard()
  local mcursor_ns = vim.api.nvim_create_namespace("nvim.multicursor")
  local mcursor_active = false

  vim.api.nvim_create_autocmd("SafeState", {
    group = vim.api.nvim_create_augroup("MulticursorClipboard", { clear = true }),
    callback = function()
      local active = #vim.api.nvim_buf_get_extmarks(0, mcursor_ns, 0, -1, { limit = 1 }) > 0
      if active == mcursor_active then
        return
      end
      mcursor_active = active
      if active then
        vim.opt.clipboard:remove { "unnamedplus" }
      else
        vim.opt.clipboard:append { "unnamedplus" }
      end
    end,
  })
end

return M
