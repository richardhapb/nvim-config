local fzf = require('fzf-lua')
local fzf_actions = require('fzf-lua.actions')

---Execute git command and handle errors properly
---@param args table Git command arguments
---@param callback? function Callback to execute on success
---@return vim.SystemObj
local function git_exec(args, callback)
  local cmd = vim.list_extend({ "git" }, args or {})
  local job = vim.system(cmd, {
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

  return job
end

---Execute a git worktree action
---@param worktree_name string worktree
---@param action string Action to perform
---@param ish string? ish to be attached in case of a new worktree
---@return vim.SystemObj?
local function worktree_action(worktree_name, action, ish)
  ish = ish or worktree_name

  local actions_map = {
    add = { 'worktree', 'add', worktree_name, ish },
    remove = { 'worktree', 'remove', worktree_name },
  }


  local args = actions_map[action]
  if not args then
    vim.notify('Unknown action: ' .. action, vim.log.levels.ERROR)
    return
  end

  return git_exec(args, function()
    action = action:gsub("e$", "")
    vim.notify(action:gsub('^%l', string.upper) .. 'ed worktree: ' .. worktree_name)
  end)
end

---Extract the worktree path
---@param worktree_line any
local function extract_worktree(worktree_line)
  return vim.split(worktree_line, " ")[1]
end

---List worktrees with fzf-lua interface
---@param opts? table fzf-lua options
local function worktrees(opts)
  opts = opts or {}

  -- Get all containers (running and stopped)
  git_exec({ 'worktree', 'list' }, function(output)
    local worktrees_list = vim.split(output, "\n", { plain = true, trimempty = true })

    if #worktrees_list > 0 then
      -- The first position is the current worktree
      table.remove(worktrees_list, 1)
    end

    if #worktrees_list == 0 then
      vim.notify('No Worktrees found', vim.log.levels.WARN)
      return
    end

    -- Create fzf picker with custom actions
    fzf.fzf_exec(worktrees_list, {
      prompt = "Git Worktrees> ",
      fzf_opts = {
        ["--ansi"]      = true,
        ["--delimiter"] = "\t",
        ["--with-nth"]  = "1,2", -- display cols only
        ["--nth"]       = "1,2", -- search only these cols
        ["--header"]    =
        "Enter: switch to worktree | C-a: add | C-d: delete",
      },
      actions = {
        ["default"] = fzf_actions.git_worktree_cd,
        ["ctrl-a"] = function(_, args)
          local worktree = args.query

          if worktree == "" then
            return
          end

          git_exec({ "branch", "--no-color", "--omit-empty", "--format", "%(refname:short)" }, function(out)
            local branches = vim.split(out, "\n", { plain = true, trimempty = true })

            vim.ui.select(branches, {
              prompt = 'Select the branch for the worktree:',
            }, function(choice)
              if not choice then
                vim.notify("Aborted", vim.log.levels.INFO)
                return
              end

              worktree_action(worktree, "add", choice):wait()
              vim.cmd('lcd ' .. vim.fs.joinpath(vim.fn.getcwd(), worktree))
            end)
          end)
        end,
        ["ctrl-d"] = function(selected)
          local worktree = extract_worktree(selected[1])
          local confirm = vim.fn.confirm(
            'Are you sure you want to delete worktree "' .. worktree .. '"?',
            '&Yes\n&No', 2)
          if confirm == 2 then
            return
          end

          worktree_action(worktree, "remove")
        end
      },
    })
  end)
end

return {
  worktree_action = worktree_action,
  worktrees = worktrees
}
