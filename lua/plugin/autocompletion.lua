local M = {}

local pending_timer = nil
local function debounce(fn, ms)
  return function(...)
    local argv = { ... }
    if pending_timer then
      pending_timer:stop(); pending_timer:close()
    end
    pending_timer = vim.loop.new_timer()
    if pending_timer ~= nil then
      pending_timer:start(ms, 0, function()
        pending_timer:stop(); pending_timer:close(); pending_timer = nil
        vim.schedule(function() fn(unpack(argv)) end)
      end)
    end
  end
end

-- Trigger only when cursor is after a word char; skip comments/strings lightly
local function should_trigger(bufnr)
  -- Basic check: previous char is wordy
  local col = vim.fn.col(".")
  if col <= 1 then return false end
  local line = vim.api.nvim_get_current_line()
  local prev = line:sub(col - 1, col - 1)
  if not prev:match("[%w_]") and not prev:match("%.") then return false end

  -- heuristic: don’t trigger inside very long lines (perf)
  if #line > 2000 then return false end

  return true
end

local function feedkeys(keys)
  vim.api.nvim_feedkeys(vim.keycode(keys), "n", false)
end

local function trigger_lsp_omni()
  if vim.fn.pumvisible() == 1 then return end
  if not should_trigger(0) then return end
  -- Ask LSP via omnifunc
  feedkeys("<C-x><C-o>")
end

-- One signature window at a time
local sig_win

vim.lsp.handlers["textDocument/signatureHelp"] = function(err, result, ctx, cfg)
  if sig_win and vim.api.nvim_win_is_valid(sig_win) then
    pcall(vim.api.nvim_win_close, sig_win, true)
    sig_win = nil
  end
  if err or not result or not result.signatures or not result.signatures[1] then
    return
  end
  local enc = (vim.lsp.get_client_by_id(ctx.client_id) or {}).offset_encoding
  local lines = vim.lsp.util.convert_signature_help_to_markdown_lines(result, enc)
  lines = vim.split(lines or {}, "\n", { trimempty = true })
  if vim.tbl_isempty(lines) then return end

  local bufnr, win = vim.lsp.util.open_floating_preview(
    lines,
    "markdown",
    {
      border = "rounded",
      focusable = false,
      close_events = { "CursorMoved", "InsertLeave", "BufHidden" }
    }
  )
  sig_win = win
end

-- Call-context detector: previous char is '(' or ','
local function maybe_sighelp()
  local col = vim.fn.col(".")
  if col <= 1 then return end
  local ch = vim.api.nvim_get_current_line():sub(col - 1, col - 1)
  if ch == "(" or ch == "," then
    vim.lsp.buf.signature_help()
  end
end

function M.setup()
  local debounced_trigger = debounce(trigger_lsp_omni, 60) -- ~60ms feels snappy

  -- Fire on insert changes and when you enter insert mode
  vim.api.nvim_create_autocmd({ "TextChangedI" }, {
    callback = function() debounced_trigger() end,
  })
  vim.api.nvim_create_autocmd({ "InsertEnter" }, {
    callback = function() vim.defer_fn(trigger_lsp_omni, 80) end,
  })

  -- Call on insert changes (debounced is fine), and when you move in the pum
  vim.api.nvim_create_autocmd("TextChangedI", {
    callback = function() maybe_sighelp() end,
  })

  -- Always insert a real newline. If the menu is open, close it first.
  vim.keymap.set("i", "<CR>", function()
    if vim.fn.pumvisible() == 1 then
      return vim.api.nvim_replace_termcodes("<C-e><CR>", true, false, true)
    end
    return vim.api.nvim_replace_termcodes("<CR>", true, false, true)
  end, { expr = true })

  vim.keymap.set("i", "<Esc>", function()
    if vim.fn.pumvisible() == 1 then return vim.api.nvim_replace_termcodes("<C-e><Esc>", true, false, true) end
    return vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
  end, { expr = true })
end

return M
