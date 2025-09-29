local fzf = require('fzf-lua')
local utils = require('fzf-lua.utils')

local M = {}

M.settings = {
  tmux = true,
  terminal_cmd = 'split' -- 'split', 'vsplit', 'tabnew'
}

M.setup = function(opts)
  opts = opts or {}
  M.settings = vim.tbl_deep_extend('force', M.settings, opts)
end

---Verify if we're running inside tmux
---@return boolean
local function is_in_tmux()
  return vim.env.TMUX ~= nil
end

---Open a terminal window or tmux pane depending on the settings
---when tmux is disabled or not available, use Vim term instead
---@param cmd table Command to run
---@param use_tmux boolean Whether to use tmux
local function open_terminal(cmd, use_tmux)
  if use_tmux and is_in_tmux() then
    -- Create a new tmux window with the command
    vim.system({ 'tmux', 'new-window', table.concat(cmd, ' ') })
  else
    -- Fallback to Neovim terminal
    local term_cmd = M.settings.terminal_cmd
    if term_cmd == 'split' then
      vim.cmd('split | terminal ' .. table.concat(cmd, ' '))
    elseif term_cmd == 'vsplit' then
      vim.cmd('vsplit | terminal ' .. table.concat(cmd, ' '))
    else
      vim.cmd('tabnew | terminal ' .. table.concat(cmd, ' '))
    end
    vim.cmd('startinsert')
  end
end

-- Available colors
--
--
-- black
-- blue
-- bold
-- clear
-- cyan
-- dark_grey
-- green
-- grey
-- italic
-- magenta
-- red
-- underline
-- white
-- yellow
--
---Assigns a highlight group based on the status of the container
---@param status string Container status
---@return string Highlight group name
local function get_status_hl(status)
  if status:find('Up') then
    return 'cyan'
  elseif status:find('Exited') then
    return 'red'
  elseif status:find('Created') then
    return 'yellow'
  else
    return 'dark_grey'
  end
end

---Make a tiny helper to extract the last tab field (the hidden key)
local function extract_key(line)
  return line and line:match("\t([^\t]+)$") or nil
end

--- Format entry: return the COLORED display columns + a final hidden key
---NOTE: use tabs between columns; last field is the key (no color)
---@param container table Container data from docker ps
---@return string, string Original and Formatted display string
local function format_entry(container)
  local name      = (container.Names or "unnamed"):gsub("^/", "")
  local image     = container.Image or "unknown"
  local status    = container.Status or "unknown"

  local colorized = table.concat({
    string.format("%-25s", utils.ansi_codes.green(name)),
    string.format("%-30s", utils.ansi_codes.blue(image)),
    utils.ansi_codes[get_status_hl(status):lower()](status),
  }, "\t")

  -- Hidden, stable key: prefer ID; fall back to name
  local key       = container.ID or name

  -- What we pass to fzf is: <col1>\t<col2>\t<col3>\t<key>
  -- with-nth will hide the last field from display.
  local fzf_line  = colorized .. "\t" .. key
  return fzf_line, key
end

---Execute docker command and handle errors properly
---@param args table Docker command arguments
---@param callback? function Callback to execute on success
local function docker_exec(args, callback)
  local cmd = vim.list_extend({ "docker" }, args or {})
  vim.system(cmd, {
    text = true
  }, function(result)
    -- Schedule the callback to run in the main event loop to avoid fast event context
    vim.schedule(function()
      if result.code == 0 then
        if callback then callback(result.stdout) end
      else
        vim.notify('Docker command failed: ' .. (result.stderr or 'Unknown error'), vim.log.levels.ERROR)
      end
    end)
  end)
end

---Execute container actions (start, stop, restart, etc.)
---@param container_id string Container ID
---@param action string Action to perform
local function container_action(container_id, action)
  local actions_map = {
    start = { 'start', container_id },
    stop = { 'stop', container_id },
    restart = { 'restart', container_id },
    remove = { 'rm', '-f', container_id },
    logs = { 'logs', '--tail', '100', '-f', container_id },
    exec = { 'exec', '-it', container_id, 'bash' },
    stats = { 'stats', container_id }
  }

  local args = actions_map[action]
  if not args then
    vim.notify('Unknown action: ' .. action, vim.log.levels.ERROR)
    return
  end

  -- Actions that require terminal interaction
  if action == 'logs' or action == 'exec' or action == 'stats' then
    open_terminal({ 'docker', unpack(args) }, M.settings.tmux)
  elseif action == 'remove' then
    docker_exec(args, function()
      vim.notify('Container removed: ' .. container_id)
    end)
  else
    -- Simple docker commands (start, stop, restart)
    docker_exec(args, function()
      vim.notify(action:gsub('^%l', string.upper) .. 'ed container: ' .. container_id)
    end)
  end
end

---Generate preview command for container details
---@param container_data table Container information
---@return string Command to generate preview
local function preview_container(container_data)
  if container_data.State == 'running' then
    -- Show recent logs for running containers
    local result = vim.system({ 'docker', 'logs', '--tail', '50', container_data.ID }):wait()
    return result.stdout
  end

  -- Show container inspect for stopped containers
  local result = vim.system({ 'sh', '-c', 'docker inspect ' .. container_data.ID .. ' | jq .' }):wait()
  return result.stdout
end

---List docker containers with fzf-lua interface
---@param opts? table fzf-lua options
M.docker_containers = function(opts)
  opts = opts or {}

  -- Get all containers (running and stopped)
  docker_exec({ 'ps', '-a', '--format', 'json' }, function(output)
    local containers = {}

    -- Parse JSON output line by line
    -- Build the sources and a map by key
    local containers_entries, container_map = {}, {}
    for line in output:gmatch("[^\r\n]+") do
      if vim.trim(line) ~= "" then
        local ok, container = pcall(vim.json.decode, line)
        if ok and container then
          local fzf_line, key = format_entry(container)
          table.insert(containers_entries, fzf_line)
          container_map[key] = container
        end
      end
    end

    if #containers_entries == 0 then
      vim.notify('No Docker containers found', vim.log.levels.WARN)
      return
    end

    -- Create fzf picker with custom actions
    -- 4) fzf picker: tell fzf to show/search only the first 3 columns (hide the key)
    fzf.fzf_exec(containers_entries, {
      prompt = "Docker Containers> ",
      fzf_opts = {
        ["--ansi"]           = true,
        ["--delimiter"]      = "\t",
        ["--with-nth"]       = "1,2,3", -- display cols only
        ["--nth"]            = "1,2,3", -- search only these cols
        ["--preview-window"] = "right:50%:wrap:follow",
        ["--header"]         =
        "Enter: logs/start | C-s: start | C-q: stop | C-d: delete | C-l: logs | C-t: shell | C-x: stats",
      },
      preview = [[docker logs -n 50 -f {4}]],
      actions = {
        ["default"] = function(selected)
          local key = extract_key(selected[1])
          local c = key and container_map[key]
          if not c then return end
          if c.State == "running" then
            container_action(c.ID, "logs")
          else
            container_action(c.ID, "start")
          end
        end,

        ["ctrl-s"] = function(selected)
          local c = container_map[extract_key(selected[1]) or ""]
          if c then container_action(c.ID, "start") end
        end,
        ["ctrl-q"] = function(selected)
          local c = container_map[extract_key(selected[1]) or ""]
          if c then container_action(c.ID, "stop") end
        end,
        ["ctrl-d"] = function(_, args)
          local q = args and args.query and vim.trim(args.query) or ""
          if q == "" then return end

          local confirm = vim.fn.confirm(
            'Are you sure you want to delete containers with prefix "' .. q .. '"?',
            '&Yes\n&No', 2)
          if confirm == 2 then
            return
          end

          for _, c in pairs(container_map) do
            if c.State ~= "running" and c.State ~= "restarting" and c.Names:match("^" .. q) then
              container_action(c.ID, "remove")
            end
          end
        end,
        ["ctrl-l"] = function(selected)
          local c = container_map[extract_key(selected[1]) or ""]
          if c then container_action(c.ID, "logs") end
        end,
        ["ctrl-t"] = function(selected)
          local c = container_map[extract_key(selected[1]) or ""]
          if c then container_action(c.ID, "exec") end
        end,
        ["ctrl-x"] = function(selected)
          local c = container_map[extract_key(selected[1]) or ""]
          if c then container_action(c.ID, "stats") end
        end,

        -- Prefix actions: use the *query*, not the displayed line
        ["ctrl-r"] = function(_, args)
          local q = args and args.query and vim.trim(args.query) or ""
          if q == "" then return end
          for _, c in pairs(container_map) do
            if c.State ~= "running" and c.State ~= "restarting" and c.Names:match("^" .. q) then
              container_action(c.ID, "start")
            end
          end
        end,
        ["ctrl-c"] = function(_, args)
          local q = args and args.query and vim.trim(args.query) or ""
          if q == "" then return end
          for _, c in pairs(container_map) do
            vim.print(c.State)
            if (c.State == "running" or c.State == "restarting") and c.Names:match("^" .. q) then
              container_action(c.ID, "stop")
            end
          end
        end,
      },
    })
  end)
end

return M
