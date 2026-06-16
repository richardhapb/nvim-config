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

---MR chooser for the current working directory. gitlab.nvim's own
---choose_merge_request hardcodes its format_item and omits the MR number, so
---we list MRs via glab ourselves to show "!<iid>" in the list, then hand the
---chosen MR's URL to open_url (same checkout + reviewer handoff).
local function choose_mr()
  local res = vim.system(
    { "glab", "mr", "list", "-F", "json", "-P", "50" },
    { text = true, cwd = vim.fn.getcwd() }
  ):wait()
  if res.code ~= 0 then
    notify("glab mr list failed: " .. vim.trim(res.stderr or ""), vim.log.levels.ERROR)
    return
  end

  local ok, mrs = pcall(vim.json.decode, res.stdout or "")
  if not ok or type(mrs) ~= "table" or #mrs == 0 then
    notify("No open merge requests in this repo", vim.log.levels.WARN)
    return
  end

  vim.ui.select(mrs, {
    prompt = "Choose Merge Request",
    format_item = function(mr)
      local author = (mr.author and (mr.author.name or mr.author.username)) or "?"
      return string.format("!%d  %s  [%s → %s]  (%s)",
        mr.iid, mr.title, mr.source_branch, mr.target_branch, author)
    end,
  }, function(choice)
    if not choice then return end
    M.open_url(choice.web_url)
  end)
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

---Locate the local clone whose `origin` points at `host`/`project`. Scans
---every repo under `M.repos_dir`, so it works no matter which Checkr repo the
---MR lives in.
---@param host string e.g. "gitlab.checkrhq.net"
---@param project string e.g. "platform/checkr"
---@return string? path
local function find_clone(host, project)
  for name, type_ in vim.fs.dir(M.repos_dir) do
    if type_ == "directory" then
      local path = vim.fs.joinpath(M.repos_dir, name)
      local url = origin_url(path)
      -- origin is either git@host:project.git or https://host/project.git;
      -- a containment check on both host and project handles both forms.
      if url
        and url:find(host, 1, true)
        and url:lower():find(project:lower(), 1, true)
      then
        return path
      end
    end
  end
  return nil
end

---Open a specific MR straight from its web URL, handing off to gitlab.nvim's
---reviewer. Accepts the bare URL or a "MR <url>" paste.
---
---The Go server resolves the MR by *source branch AND iid* (see gitlab.nvim's
---withMrMiddleware), so we must check out the source branch before opening —
---which is also what gitlab.nvim's own choose_merge_request does.
---@param input string
function M.open_url(input)
  -- Drop an optional leading "MR " label, then isolate the URL.
  local url = vim.trim((input or ""):gsub("^%s*[Mm][Rr]%s+", ""))

  local host, project, iid = url:match("https?://([^/]+)/(.-)/%-/merge_requests/(%d+)")
  if not iid then
    notify("Not a GitLab MR URL: " .. url, vim.log.levels.ERROR)
    return
  end

  local repo = find_clone(host, project)
  if not repo then
    notify(("No local clone of %s/%s under %s"):format(host, project, M.repos_dir), vim.log.levels.WARN)
    return
  end

  local ok, gitlab = pcall(require, "gitlab")
  if not ok then
    notify("gitlab.nvim is not available", vim.log.levels.ERROR)
    return
  end

  -- Keep the cwd change tab-local so gitlab.nvim and glab both resolve here.
  vim.cmd.tcd(repo)

  -- Ask glab (run inside the repo) for the MR's source branch.
  local res = vim.system({ "glab", "mr", "view", iid, "-F", "json" }, { text = true, cwd = repo }):wait()
  if res.code ~= 0 then
    notify(("glab mr view %s failed: %s"):format(iid, vim.trim(res.stderr or "")), vim.log.levels.ERROR)
    return
  end
  local jok, mr = pcall(vim.json.decode, res.stdout or "")
  if not jok or type(mr) ~= "table" or not mr.source_branch then
    notify("Could not read source branch for MR " .. iid, vim.log.levels.ERROR)
    return
  end
  local branch = mr.source_branch

  local git = require("gitlab.git")
  local reviewer = require("gitlab.reviewer")
  local state = require("gitlab.state")

  if reviewer.is_open then reviewer.close() end

  if branch ~= git.get_current_branch() then
    local clean, clean_err = git.has_clean_tree()
    if clean_err ~= nil then return end
    if not clean then
      notify("Working tree has changes; stash or commit before switching to " .. branch, vim.log.levels.ERROR)
      return
    end
    -- Make sure the branch exists locally, then check it out.
    vim.system({ "git", "fetch", "origin", branch }, { cwd = repo }):wait()
    local _, switch_err = git.switch_branch(branch)
    if switch_err ~= nil then
      notify("Could not check out " .. branch, vim.log.levels.ERROR)
      return
    end
  end

  vim.schedule(function()
    -- gitlab.nvim resolves auth_provider (gitlab_url/auth_token) lazily inside
    -- its async sequences. We start the server directly, so do it ourselves —
    -- otherwise the Go server dies with "GitLab instance URL cannot be empty".
    if not state.set_plugin_configuration() then return end

    state.chosen_mr_iid = tonumber(iid)
    local server = require("gitlab.server")
    local function open()
      gitlab.review()
      notify(("Reviewing MR !%s (%s)"):format(iid, branch))
    end
    -- restart() picks up the new cwd/branch/iid when the server is already
    -- up; but on the first MR of a session it isn't running yet (the chooser
    -- only works because its dependency fetch boots it first), so start it.
    if state.go_server_running then
      server.restart(open)
    else
      server.build_and_start(open)
    end
  end)
end

function M.setup()
  vim.api.nvim_create_user_command("CheckrMR", M.pick,
    { desc = "Pick a Checkr repo and choose an MR to review" })

  -- `:CheckrMROpen <url>` — or run it with no argument to use the URL on the
  -- system clipboard. The "MR " prefix is stripped either way.
  vim.api.nvim_create_user_command("CheckrMROpen", function(opts)
    local arg = vim.trim(opts.args)
    if arg == "" then arg = vim.fn.getreg("+") end
    M.open_url(arg)
  end, { nargs = "*", desc = "Open a GitLab MR by URL in gitlab.nvim" })

  vim.keymap.set("n", "<leader>M", M.pick,
    { silent = true, desc = "Pick a Checkr repo + MR to review" })

  vim.keymap.set("n", "<leader>mo", function() M.open_url(vim.fn.getreg("+")) end,
    { silent = true, desc = "Open GitLab MR from clipboard URL" })
end

return M
