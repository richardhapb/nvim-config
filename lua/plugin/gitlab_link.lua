local M = {}

---Run git synchronously and return trimmed stdout, or nil on failure.
---@param args string[]
---@return string?
local function git(args)
  local cmd = vim.list_extend({ "git" }, args)
  local result = vim.system(cmd, { text = true }):wait()
  if result.code ~= 0 then
    return nil
  end
  return vim.trim(result.stdout or "")
end

---Parse a git remote URL into host + project path.
---@param url string
---@return string?, string?
local function parse_remote(url)
  url = vim.trim(url)
  local host, path = url:match("^git@([^:]+):(.+)$")
  if not host then
    host, path = url:match("^https?://[^/]*@?([^/]+)/(.+)$")
  end
  if not path then return nil, nil end
  path = path:gsub("%.git/?$", "")
  return host, path
end

---Resolve the remote default branch.
---@return string
local function default_branch()
  local ref = git({ "symbolic-ref", "--short", "refs/remotes/origin/HEAD" })
  if ref and ref ~= "" then
    return (ref:gsub("^origin/", ""))
  end

  for _, b in ipairs({ "main", "master" }) do
    if git({ "show-ref", "--verify", "--quiet", "refs/remotes/origin/" .. b }) ~= nil then
      return b
    end
  end

  return "main"
end

---@param line1 integer
---@param line2 integer
---@return string?
local function build_url(line1, line2)
  local abs = vim.api.nvim_buf_get_name(0)
  if abs == "" then
    vim.notify("Buffer has no file name", vim.log.levels.ERROR, { title = "GitlabLink" })
    return nil
  end

  local remote = git({ "remote", "get-url", "origin" })
  if not remote then
    vim.notify("No 'origin' remote", vim.log.levels.ERROR, { title = "GitlabLink" })
    return nil
  end

  local host, proj = parse_remote(remote)
  if not host or not proj then
    vim.notify("Could not parse remote: " .. remote, vim.log.levels.ERROR, { title = "GitlabLink" })
    return nil
  end

  local toplevel = git({ "rev-parse", "--show-toplevel" })
  if not toplevel or toplevel == "" then
    vim.notify("Not inside a git worktree", vim.log.levels.ERROR, { title = "GitlabLink" })
    return nil
  end

  if abs:sub(1, #toplevel + 1) ~= toplevel .. "/" then
    vim.notify("File is outside the git root", vim.log.levels.ERROR, { title = "GitlabLink" })
    return nil
  end
  local rel = abs:sub(#toplevel + 2)

  local anchor = line1 == line2
      and ("#L" .. line1)
      or ("#L" .. line1 .. "-" .. line2)

  return string.format("https://%s/%s/-/blob/%s/%s?ref_type=heads%s",
    host, proj, default_branch(), rel, anchor)
end

function M.setup()
  vim.api.nvim_create_user_command("GitlabLink", function(args)
    local url = build_url(args.line1, args.line2)
    if not url then return end
    vim.fn.setreg('+', url)
    vim.fn.setreg('"', url)
    vim.notify("Copied " .. url, vim.log.levels.INFO, { title = "GitlabLink" })
  end, { range = true })

  vim.keymap.set({ "n", "x" }, "<leader>C", ":GitlabLink<CR>",
    { silent = true, desc = "Copy GitLab permalink" })
end

return M
