local M = { text = "" }

function M.setup()
  vim.api.nvim_create_autocmd("LspProgress", {
    group = vim.api.nvim_create_augroup("LspProgressBar", { clear = true }),
    callback = function(ev)
      local value = ev.data.params.value or {}
      local msg = value.message
      if msg == vim.NIL or not msg then
        msg = "done"
      end

      -- rust analyzer in particular has really long LSP messages so truncate them
      if #msg > 40 then
        msg = msg:sub(1, 37) .. "..."
      end

      local percent = value.percentage or 100

      -- 'statusline' evaluates this text with %-items reprocessed (%f, %=, etc.
      -- need that), so a literal "%" here must be doubled or "%]" reads as the
      -- statusline's own end-highlight-group item and gets swallowed.
      M.text = value.kind == "end" and ""
        or string.format("[%3d%%%%] %s: %s", percent, value.title or "", msg)
      vim.cmd.redrawstatus()

      if not value.kind then return end

      local status = value.kind == "end" and 0 or 1
      local osc_seq = string.format("\27]9;4;%d;%d\a", status, percent)
      if os.getenv("TMUX") then
        osc_seq = string.format("\27Ptmux;\27%s\27\\", osc_seq)
      end

      io.stdout:write(osc_seq)
      io.stdout:flush()
    end,
  })
end

return M
