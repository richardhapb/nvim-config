-- Per-project session persistence, in the spirit of Zed: launch `nvim` with no
-- file arguments inside a directory and your buffers, windows and tabs from
-- last time are restored. Sessions are keyed by cwd, so each git worktree keeps
-- its own independent layout.

local M = {}

local session_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "sessions")

---Path of the session file for the current working directory.
---@return string
local function session_file()
  -- Encode the cwd into a flat, filesystem-safe filename.
  local key = vim.fn.getcwd():gsub("[\\/:]+", "%%")
  return vim.fs.joinpath(session_dir, key .. ".vim")
end

---Write the current session for this cwd.
function M.save()
  vim.fn.mkdir(session_dir, "p")
  vim.cmd("mksession! " .. vim.fn.fnameescape(session_file()))
end

---Restore the session for this cwd, if one exists. Returns true on restore.
---@return boolean
function M.restore()
  local file = session_file()
  if vim.fn.filereadable(file) == 0 then
    return false
  end
  vim.cmd("silent! source " .. vim.fn.fnameescape(file))
  return true
end

---Delete the saved session for this cwd.
function M.delete()
  local file = session_file()
  if vim.fn.filereadable(file) == 1 then
    vim.fn.delete(file)
    vim.notify("Session deleted", vim.log.levels.INFO)
  end
end

function M.setup()
  -- Keep blank/help/terminal buffers out of the saved layout; remember more.
  vim.opt.sessionoptions = {
    "buffers", "curdir", "folds", "tabpages", "winsize", "winpos", "globals",
  }

  local group = vim.api.nvim_create_augroup("Session", { clear = true })

  -- Auto-save on exit, but only for "project" sessions: started with no file
  -- args and not piping from stdin. Editing a single file stays ephemeral.
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      if vim.g.session_active then
        M.save()
      end
    end,
  })

  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    nested = true, -- so restored buffers fire their own FileType/LSP autocmds
    callback = function()
      if vim.fn.argc() ~= 0 or vim.g.std_in then
        return
      end
      vim.g.session_active = true
      M.restore()
    end,
  })

  -- Detect stdin so `… | nvim` never triggers auto-restore.
  vim.api.nvim_create_autocmd("StdinReadPre", {
    group = group,
    callback = function() vim.g.std_in = true end,
  })

  vim.api.nvim_create_user_command("SessionSave", function()
    M.save()
    vim.g.session_active = true
    vim.notify("Session saved", vim.log.levels.INFO)
  end, { desc = "Save session for cwd" })
  vim.api.nvim_create_user_command("SessionRestore", M.restore, { desc = "Restore session for cwd" })
  vim.api.nvim_create_user_command("SessionDelete", M.delete, { desc = "Delete session for cwd" })
end

return M
