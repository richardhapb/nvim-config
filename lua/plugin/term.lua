-- Persistent toggle terminal, in the spirit of the Zed/VSCode panel: the shell
-- process and its scrollback survive hide/show. A single global terminal is
-- kept alive; toggling only creates/destroys the *window*, never the buffer.

local M = {}

local state = {
  buf = nil,    ---@type integer? terminal buffer (persists across toggles)
  win = nil,    ---@type integer? window currently showing the terminal
  job = nil,    ---@type integer? job id of the shell
  height = 15,  ---@type integer remembered window height
}

local function buf_valid()
  return state.buf ~= nil and vim.api.nvim_buf_is_valid(state.buf)
end

local function win_valid()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

---Spawn the shell into a fresh, hidden buffer.
local function spawn()
  state.buf = vim.api.nvim_create_buf(false, false) -- listed=false, scratch=false
  vim.api.nvim_buf_call(state.buf, function()
    state.job = vim.fn.jobstart(vim.o.shell, { term = true })
  end)

  -- When the shell exits, drop the buffer so the next toggle starts fresh.
  vim.api.nvim_create_autocmd("TermClose", {
    buffer = state.buf,
    callback = function()
      if win_valid() then
        vim.api.nvim_win_close(state.win, true)
      end
      if buf_valid() then
        vim.api.nvim_buf_delete(state.buf, { force = true })
      end
      state.buf, state.win, state.job = nil, nil, nil
    end,
  })
end

---Show the terminal in a bottom split.
local function open()
  if not buf_valid() then
    spawn()
  end

  vim.cmd("botright " .. state.height .. "split")
  state.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.win, state.buf)

  -- No line numbers / sign column in the terminal panel.
  vim.api.nvim_set_option_value("number", false, { win = state.win })
  vim.api.nvim_set_option_value("relativenumber", false, { win = state.win })
  vim.api.nvim_set_option_value("signcolumn", "no", { win = state.win })

  vim.cmd.startinsert()
end

---Hide the terminal window, remembering its height. Process keeps running.
local function close()
  if win_valid() then
    state.height = vim.api.nvim_win_get_height(state.win)
    vim.api.nvim_win_hide(state.win)
  end
  state.win = nil
end

---Toggle the terminal window open/closed.
function M.toggle()
  if win_valid() then
    close()
  else
    open()
  end
end

---Focus the terminal if visible, otherwise open it. Handy from another window.
function M.focus()
  if win_valid() then
    vim.api.nvim_set_current_win(state.win)
    vim.cmd.startinsert()
  else
    open()
  end
end

function M.setup()
  -- Ctrl-/ mirrors the VSCode/Zed toggle shortcut (many terminals send <C-_>).
  vim.keymap.set({ "n", "t" }, "<C-/>", M.toggle, { silent = true, desc = "Toggle terminal" })
  vim.keymap.set({ "n", "t" }, "<C-_>", M.toggle, { silent = true, desc = "Toggle terminal" })
  vim.keymap.set("n", "<leader>cb", M.toggle, { silent = true, desc = "Toggle persistent terminal" })
end

return M
