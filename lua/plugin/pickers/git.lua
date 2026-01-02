local fzf = require('fzf-lua')
local fzfutils = require('fzf-lua.utils')
local utils = require('functions.utils')

local M = {}

---Execute git command and handle errors properly
---@param args table Docker command arguments
---@param callback? function Callback to execute on success
local function git_exec(args, callback)
  local cmd = vim.list_extend({ "git" }, args or {})
  vim.system(cmd, {
    text = true
  }, function(result)
    -- Schedule the callback to run in the main event loop to avoid fast event context
    vim.schedule(function()
      if result.code == 0 then
        if callback then callback(result.stdout) end
      else
        vim.notify('Git command failed: ' .. (result.stderr or 'Unknown error'), vim.log.levels.ERROR)
      end
    end)
  end)
end

local function git_diff_name_only(branch)
  if branch == nil then
    vim.notify("No branch selected", vim.log.levels.ERROR)
    return
  end

  git_exec({ "diff", "--word-diff", branch, "--name-only" }, function(stdout)
    if stdout ~= "" then
      vim.notify("Git diff made successfully", vim.log.levels.INFO)
    else
      vim.notify("Git diff failed", vim.log.levels.ERROR)
      return
    end

    -- Verify if the buffer already exists
    local buffer = vim.fn.bufnr("Git diff: " .. branch)
    if buffer == -1 then
      buffer = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(buffer, "Git diff: " .. branch)
    end

    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, vim.split(stdout, "\n", { plain = true }))
    vim.api.nvim_set_current_buf(buffer)

    vim.keymap.set('n', '<CR>', function() utils.git_curr_line_diff_split(branch, buffer) end, { buffer = buffer })
    vim.keymap.set('n', 'R', function() utils.git_restore_curr_line(branch) end, { buffer = buffer })
  end)
end

---@class Branch
---@field active boolean
---@field ref string
---@field author string
---@field date string

local Branch = {}
Branch.__index = Branch

---Create a new branch object
---@param active boolean
---@param ref string
---@param author string
---@param date string
function Branch:new(active, ref, author,  date)
  local branch = {}
  setmetatable(branch, Branch)
  branch.active = active
  branch.ref = ref
  branch.author = author
  branch.date = date

  return branch
end

---Parse a line and get a Branch object
---@param line string
---@return Branch
function Branch:from_line(line)
  local escape = false
  local count = 0
  local element = ""
  local elements = {}

  for i = 1, #line do
    local c = line:sub(i, i)
    if c ~= "'" or escape then
      element = element .. c
    end

    if c == "'" and not escape then
      count = count + 1
      if count % 2 == 0 then
        if element == "*" or element == " " then
          table.insert(elements, element == "*")
        else
          table.insert(elements, element)
        end
        element = ""
      end
    end

    escape = c == "\\" and not escape
  end

  local branch = Branch:new(unpack(elements))

  return branch
end

---Parse the branches from output
---@param output string
---@return Branch[]
local function extract_branches(output)
  local branches = {}
  for _, line in ipairs(vim.split(output, '\n')) do
    if vim.trim(line) ~= "" then
      table.insert(branches, Branch:from_line(line))
    end
  end

  return branches
end

---@param branches Branch[]
---@param field string
---@return integer
local function get_max_length(branches, field)
  local max = 0
  for _, branch in ipairs(branches) do
    if #branch[field] > max then
      max = #branch[field]
    end
  end

  return max
end


---Format the branch to Fzf Lua format
---@param branch Branch
---@param max_ref integer
local function format_entry(branch, max_ref)
  local active = branch.active and "[*]" or "[ ]"
  local ref = branch.ref or ""
  local date = branch.date or ""

  local colorized = string.format(
    "%-5s %-" .. max_ref + 11 .. "s %-50s",
    fzfutils.ansi_codes.cyan(active),
    fzfutils.ansi_codes.green(ref),
    fzfutils.ansi_codes.red(date)
  )

  return colorized .. "\t" .. ref
end

---List docker containers with fzf-lua interface
---@param opts? table fzf-lua options
M.git_branches_diff = function(opts)
  opts = opts or {}
  local format = "%(HEAD)"
      .. "%(refname)"
      .. "%(authorname)"
      .. "%(committerdate:format-local:%Y/%m/%d %H:%M:%S)"

  -- Get all containers (running and stopped)
  git_exec({ "for-each-ref", "--perl", "--format", format }, function(output)
    local branches = extract_branches(output)

    if #branches == 0 then
      vim.notify('No branches found', vim.log.levels.WARN)
      return
    end

    local max_ref = get_max_length(branches, "ref")
    local fzf_branches = {}
    local branches_map = {}

    --- Helper to extract the last tab field (the hidden key)
    local function extract_key(line)
      return line and line:match("\t([^\t]+)$") or nil
    end

    for _, branch in ipairs(branches) do
      local entry = format_entry(branch, max_ref)
      table.insert(fzf_branches, entry)
      local key = extract_key(entry) or ''
      branches_map[key] = branch
    end

    -- Create fzf picker with custom actions
    -- nth tells fzf to show/search only the first 3 columns (hide the key)
    fzf.fzf_exec(fzf_branches, vim.tbl_deep_extend("force", {
      prompt = "Git Branches> ",
      fzf_opts = {
        ["--ansi"]           = true,
        ["--delimiter"]      = "\t",
        ["--with-nth"]       = "{1}", -- display cols only
        ["--preview-window"] = "right:50%:wrap",
        ["--header"]         =
        "Enter: Open diff",
      },
      preview = [[git diff --color {2}]],
      actions = {
        ["default"] = function(selected)
          local b = branches_map[extract_key(selected[1]) or ""]
          if b == nil then
            vim.notify("Branch not found in map", vim.log.levels.ERROR)
            return
          end
          git_diff_name_only(b.ref)
        end,
      },
    }, opts))
  end)
end

return M
