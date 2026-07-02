-- gh_pr.lua
--
-- The GitHub counterpart to checkr_mr.lua: a thin repo selector that hands off
-- to octo.nvim for the actual PR review. octo.nvim works on the repo you have
-- checked out (it reads the gh remote from cwd), so the only gap it leaves is
-- "which repo / which PR am I reviewing?" — this fills that:
--
--   <leader>P / :GhPR  -> fzf-lua pick a local GitHub clone, tcd into it,
--                         then choose a PR (gh pr list) and open octo.
--
-- Everything after picking the PR (diff, inline comments, threads, approve) is
-- octo.nvim — see its keymaps wired in config/mini_plugins.lua. GitHub is a
-- personal account (distinct from the Checkr GitLab side in checkr_mr.lua);
-- auth comes from the already-authenticated `gh` CLI.
--
-- Conventions mirror checkr_mr.lua: a "GhPR" notify title and the trailing-tab
-- hidden-key trick for fzf entries.

local M = {}

local TITLE = "GhPR"

-- Roots under which clones live (one dir per repo). Same set tmux-mr scans, so
-- personal GitHub clones resolve no matter which of the usual roots they sit in.
M.repos_dirs = {
  vim.env.DEV,
  vim.fs.joinpath(vim.fn.expand("$HOME"), "proj"),
  vim.fs.joinpath(vim.fn.expand("$HOME"), "dev"),
  vim.env.DEV and vim.fs.joinpath(vim.env.DEV, "cont") or nil,
}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = TITLE })
end

---Whether a host string is GitHub.
---@param host string?
---@return boolean
function M.is_github(host)
  return host ~= nil and host:match("github") ~= nil
end

---Read a repo's `origin` URL, or nil if it isn't a git repo / has no origin.
---@param dir string
---@return string?
local function origin_url(dir)
  local res = vim.system({ "git", "-C", dir, "remote", "get-url", "origin" }, { text = true }):wait()
  if res.code ~= 0 then return nil end
  return vim.trim(res.stdout or "")
end

---Iterate every immediate subdirectory across all configured repo roots,
---deduplicating roots that resolve to the same path.
---@param fn fun(name: string, path: string)
local function each_clone(fn)
  local seen = {}
  for _, root in ipairs(M.repos_dirs) do
    if root and root ~= "" and vim.fn.isdirectory(root) == 1 then
      local real = vim.fn.fnamemodify(root, ":p")
      if not seen[real] then
        seen[real] = true
        for name, type_ in vim.fs.dir(root) do
          if type_ == "directory" then
            fn(name, vim.fs.joinpath(root, name))
          end
        end
      end
    end
  end
end

---PR chooser for the current working directory. Lists PRs via `gh` so we can
---show "#<num>" in the list, then hands the chosen PR to review_in.
local function choose_pr()
  local res = vim.system(
    { "gh", "pr", "list", "--json", "number,title,headRefName,baseRefName,author,isDraft", "-L", "50" },
    { text = true, cwd = vim.fn.getcwd() }
  ):wait()
  if res.code ~= 0 then
    notify("gh pr list failed: " .. vim.trim(res.stderr or ""), vim.log.levels.ERROR)
    return
  end

  local ok, prs = pcall(vim.json.decode, res.stdout or "")
  if not ok or type(prs) ~= "table" or #prs == 0 then
    notify("No open pull requests in this repo", vim.log.levels.WARN)
    return
  end

  vim.ui.select(prs, {
    prompt = "Choose Pull Request",
    format_item = function(pr)
      local author = (pr.author and (pr.author.name or pr.author.login)) or "?"
      local draft = pr.isDraft and " [draft]" or ""
      return string.format("#%d  %s%s  [%s -> %s]  (%s)",
        pr.number, pr.title, draft, pr.headRefName, pr.baseRefName, author)
    end,
  }, function(choice)
    if not choice then return end
    M.review_in(vim.fn.getcwd(), choice.number)
  end)
end

---fzf-lua picker over local GitHub clones under the configured roots. Selecting
---one switches the tab's cwd into it and opens the PR chooser there.
function M.pick()
  local entries = {}
  each_clone(function(name, path)
    local url = origin_url(path)
    -- Only surface GitHub clones — that's all octo.nvim can review here.
    if url and M.is_github(url) then
      -- "<name>\t<path>"; the trailing tab field is the hidden key.
      table.insert(entries, name .. "\t" .. path)
    end
  end)

  if #entries == 0 then
    notify("No GitHub clones found under the configured repo roots", vim.log.levels.WARN)
    return
  end

  local fzf = require("fzf-lua")

  local function path_of(sel)
    return sel and sel:match("\t([^\t]+)$") or nil
  end

  fzf.fzf_exec(entries, {
    prompt = "GitHub repo> ",
    fzf_opts = {
      ["--delimiter"] = "\t",
      ["--with-nth"]  = "{1}", -- show repo name only, hide the path key
      ["--header"]    = "Enter: choose PR to review",
    },
    actions = {
      ["default"] = function(selected)
        local path = path_of(selected and selected[1])
        if not path then return end
        -- tcd keeps the cwd change local to this tab so octo and gh both
        -- resolve the right repo without disturbing other tabs.
        vim.cmd.tcd(path)
        choose_pr()
      end,
    },
  })
end

---Locate the local clone whose `origin` points at `host`/`project`. Scans every
---repo under the configured roots, so it works no matter which clone the PR
---lives in.
---@param host string e.g. "github.com"
---@param project string e.g. "richardhapb/dotfiles"
---@return string? path
local function find_clone(host, project)
  local found
  each_clone(function(_, path)
    if found then return end
    local url = origin_url(path)
    -- origin is either git@host:project.git or https://host/project.git;
    -- a containment check on both host and project handles both forms.
    if url
      and url:find(host, 1, true)
      and url:lower():find(project:lower(), 1, true)
    then
      found = path
    end
  end)
  return found
end

---Check out PR <num>'s head branch in `repo` and open octo.nvim's reviewer
---there. The branch is checked out first so diffs, LSP and local context all
---resolve against the PR's code (octo itself reads the PR from the gh remote).
---@param repo string  absolute path to the repo / worktree to review in
---@param num string|number  PR number
function M.review_in(repo, num)
  num = tostring(num)

  local ok = pcall(require, "octo")
  if not ok then
    notify("octo.nvim is not available", vim.log.levels.ERROR)
    return
  end

  -- Keep the cwd change tab-local so octo and gh both resolve here.
  vim.cmd.tcd(repo)

  -- Ask gh (run inside the repo) for the PR's head branch.
  local res = vim.system(
    { "gh", "pr", "view", num, "--json", "headRefName", "-q", ".headRefName" },
    { text = true, cwd = repo }
  ):wait()
  if res.code ~= 0 then
    notify(("gh pr view %s failed: %s"):format(num, vim.trim(res.stderr or "")), vim.log.levels.ERROR)
    return
  end
  local branch = vim.trim(res.stdout or "")
  if branch == "" then
    notify("Could not read head branch for PR #" .. num, vim.log.levels.ERROR)
    return
  end

  local function current_branch()
    local r = vim.system({ "git", "branch", "--show-current" }, { text = true, cwd = repo }):wait()
    return vim.trim(r.stdout or "")
  end

  if branch ~= current_branch() then
    -- Refuse to clobber uncommitted work (mirrors checkr_mr's clean-tree guard).
    local st = vim.system({ "git", "status", "--porcelain" }, { text = true, cwd = repo }):wait()
    if vim.trim(st.stdout or "") ~= "" then
      notify("Working tree has changes; stash or commit before switching to " .. branch, vim.log.levels.ERROR)
      return
    end
    -- `gh pr checkout` fetches the PR head and checks it out, handling forks
    -- and detached heads the way the GitHub workflow expects.
    local co = vim.system({ "gh", "pr", "checkout", num }, { text = true, cwd = repo }):wait()
    if co.code ~= 0 then
      notify(("Could not check out PR #%s: %s"):format(num, vim.trim(co.stderr or "")), vim.log.levels.ERROR)
      return
    end
  end

  -- GitHub allows only one pending review per PR. If one already exists (e.g.
  -- a half-finished earlier review), `Octo review start` errors — resume it
  -- instead. The reviews endpoint only returns PENDING reviews to their author,
  -- so a non-zero count means *our* pending review.
  local pend = vim.system(
    { "gh", "api", ("repos/{owner}/{repo}/pulls/%s/reviews"):format(num),
      "--jq", '[.[] | select(.state == "PENDING")] | length' },
    { text = true, cwd = repo }
  ):wait()
  local review_cmd = (pend.code == 0 and vim.trim(pend.stdout or "") ~= "0")
    and "Octo review resume" or "Octo review start"

  vim.schedule(function()
    -- Load the PR buffer, then open the review. octo loads the PR async, so
    -- defer the review command a touch; if it races, <leader>ghr starts it.
    vim.cmd("Octo pr edit " .. num)
    vim.defer_fn(function()
      pcall(vim.cmd, review_cmd)
      notify(("Reviewing PR #%s (%s)"):format(num, branch))
    end, 250)
  end)
end

---Open a specific PR straight from its web URL, handing off to octo.nvim's
---reviewer. Accepts the bare URL or a "PR <url>" paste.
---@param input string
function M.open_url(input)
  -- Drop an optional leading "PR " label, then isolate the URL.
  local url = vim.trim((input or ""):gsub("^%s*[Pp][Rr]%s+", ""))

  local host, project, num = url:match("https?://([^/]+)/(.-)/pull/(%d+)")
  if not num then
    notify("Not a GitHub PR URL: " .. url, vim.log.levels.ERROR)
    return
  end

  local repo = find_clone(host, project)
  if not repo then
    notify(("No local clone of %s/%s under the configured repo roots"):format(host, project), vim.log.levels.WARN)
    return
  end

  M.review_in(repo, num)
end

function M.setup()
  vim.api.nvim_create_user_command("GhPR", M.pick,
    { desc = "Pick a GitHub repo and choose a PR to review" })

  -- `:GhPROpen <url>` — or run it with no argument to use the URL on the
  -- system clipboard. The "PR " prefix is stripped either way.
  vim.api.nvim_create_user_command("GhPROpen", function(opts)
    local arg = vim.trim(opts.args)
    if arg == "" then arg = vim.fn.getreg("+") end
    M.open_url(arg)
  end, { nargs = "*", desc = "Open a GitHub PR by URL in octo.nvim" })

  -- `:GhPRReview <num>` — review PR <num> in the CURRENT repo/worktree.
  -- Used by the `tmux-mr` script, which opens nvim inside a per-PR worktree.
  vim.api.nvim_create_user_command("GhPRReview", function(opts)
    local num = vim.trim(opts.args)
    if num == "" then
      notify("GhPRReview needs a PR number", vim.log.levels.ERROR)
      return
    end
    M.review_in(vim.fn.getcwd(), num)
  end, { nargs = 1, desc = "Review a GitHub PR by number in the current repo" })

  vim.keymap.set("n", "<leader>P", M.pick,
    { silent = true, desc = "Pick a GitHub repo + PR to review" })
end

return M
