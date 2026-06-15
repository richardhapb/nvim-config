-- checkr_mr.lua
--
-- A thin repo selector that hands off to gitlab.nvim for the actual review.
-- gitlab.nvim works on the repo you have checked out, so the only gap it leaves
-- is "which repo am I reviewing in?" — this fills that:
--
--   <leader>M / :CheckrMR  -> fzf-lua pick a local GitLab clone, tcd into it,
--                             then open gitlab.nvim's MR chooser (which lists,
--                             checks out, and opens the reviewer pane).
--
-- Everything after picking the MR (diff, inline comments, approve, threads) is
-- gitlab.nvim — see its keymaps wired in config/mini_plugins.lua.
--
-- Conventions mirror git_link.lua / pickers/git.lua: a "CheckrMR" notify title
-- and the trailing-tab hidden-key trick for fzf entries.

local M = {}

local TITLE = "CheckrMR"

-- Base directory under which GitLab repos are cloned (one dir per repo).
M.repos_dir = vim.fs.joinpath(vim.fn.expand("$HOME"), "dev")

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = TITLE })
end

---Read a repo's `origin` URL, or nil if it isn't a git repo / has no origin.
---@param dir string
---@return string?
local function origin_url(dir)
  local res = vim.system({ "git", "-C", dir, "remote", "get-url", "origin" }, { text = true }):wait()
  if res.code ~= 0 then return nil end
  return vim.trim(res.stdout or "")
end

---Open gitlab.nvim's MR chooser for the current working directory.
local function choose_mr()
  local ok, gitlab = pcall(require, "gitlab")
  if not ok then
    notify("gitlab.nvim is not available", vim.log.levels.ERROR)
    return
  end
  -- Lists open MRs, checks out the chosen branch, and opens the reviewer pane.
  gitlab.choose_merge_request()
end

---fzf-lua picker over local GitLab clones under `M.repos_dir`. Selecting one
---switches the tab's cwd into it and opens the MR chooser there.
function M.pick()
  local entries = {}
  for name, type_ in vim.fs.dir(M.repos_dir) do
    if type_ == "directory" then
      local path = vim.fs.joinpath(M.repos_dir, name)
      local url = origin_url(path)
      -- Only surface GitLab clones — that's all gitlab.nvim can review.
      if url and url:match("gitlab") then
        -- "<name>\t<path>"; the trailing tab field is the hidden key.
        table.insert(entries, name .. "\t" .. path)
      end
    end
  end

  if #entries == 0 then
    notify("No GitLab clones found under " .. M.repos_dir, vim.log.levels.WARN)
    return
  end

  local fzf = require("fzf-lua")

  local function path_of(sel)
    return sel and sel:match("\t([^\t]+)$") or nil
  end

  fzf.fzf_exec(entries, {
    prompt = "Checkr repo> ",
    fzf_opts = {
      ["--delimiter"] = "\t",
      ["--with-nth"]  = "{1}", -- show repo name only, hide the path key
      ["--header"]    = "Enter: choose MR to review",
    },
    actions = {
      ["default"] = function(selected)
        local path = path_of(selected and selected[1])
        if not path then return end
        -- tcd keeps the cwd change local to this tab so gitlab.nvim and glab
        -- both resolve the right repo without disturbing other tabs.
        vim.cmd.tcd(path)
        choose_mr()
      end,
    },
  })
end

function M.setup()
  vim.api.nvim_create_user_command("CheckrMR", M.pick,
    { desc = "Pick a Checkr repo and choose an MR to review" })

  vim.keymap.set("n", "<leader>M", M.pick,
    { silent = true, desc = "Pick a Checkr repo + MR to review" })
end

return M
