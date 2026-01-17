local fzf = require('fzf-lua')
local fzfutils = require('fzf-lua.utils')
local utils = require 'functions.utils'

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

--- Open a new buffer with the command's stdout/stderr (synchronous).
--- WARNING: blocks Neovim until the command finishes.
---@param cmd string[] Command to run
local function open_buffer(cmd)
  -- capture text output
  local result = vim.system(cmd, { text = true }):wait()

  local out = result.stdout or ""
  local err = result.stderr or ""
  local text = out
  if err ~= "" then
    text = (text ~= "" and (text .. "\n") or "") .. err
  end
  if text == "" then
    text = string.format("<no output> (exit code %s)", tostring(result.code))
  end

  local lines = vim.split(text, "\n", { plain = true, trimempty = true })

  vim.cmd("new")
  local buf = vim.api.nvim_get_current_buf()

  -- make it a scratch log buffer
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("buflisted", false, { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
  vim.api.nvim_set_option_value("filetype", "log", { buf = buf })

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local n = vim.api.nvim_buf_line_count(buf)
  if n > 0 then
    vim.api.nvim_win_set_cursor(0, { n, 0 }) -- last line, column 0
  end
end


---Open a terminal window or tmux pane depending on the settings
---when tmux is disabled or not available, use Vim term instead
---@param cmd table Command to run
---@param use_tmux boolean Whether to use tmux
local function open_terminal(cmd, use_tmux)
  if use_tmux and is_in_tmux() then
    -- Create a new tmux window with the command
    vim.system({ 'tmux', 'new-window', unpack(cmd) })
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

--- Helper to extract the last tab field (the hidden key)
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
    string.format("%-25s", fzfutils.ansi_codes.green(name)),
    string.format("%-30s", fzfutils.ansi_codes.blue(image)),
    fzfutils.ansi_codes[get_status_hl(status):lower()](status),
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
    logs_buf = { 'logs', '--tail', '1000', container_id },
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
  elseif action == 'logs_buf' then
    open_buffer({ 'docker', unpack(args) })
  else
    -- Simple docker commands (start, stop, restart)
    docker_exec(args, function()
      vim.notify(action:gsub("stop", "stopp"):gsub('^%l', string.upper) .. 'ed container: ' .. container_id)
    end)
  end
end

---Sort the containers by the provided key
---@param raw_data string The data of the containers from docker output
---@param order string[] A list for the state order
---@return Iter<table> ordered containers by State
local function sort_containers_by_state(raw_data, order)
  ---@type table<integer>
  local containers_by_order = {}
  ---@type table<string, integer>

  local state_to_int = {}

  for i, state in ipairs(order) do
    containers_by_order[i] = {}
    state_to_int[state] = i
  end


  for line in raw_data:gmatch("[^\r\n]+") do
    if vim.trim(line) ~= "" then
      local ok, container = pcall(vim.json.decode, line)
      if ok and container then
        local state = container.State or "unknown"
        local target_state = containers_by_order[state_to_int[state]]
        -- If it is not in the list, append to the end
        if not target_state then
          containers_by_order[#containers_by_order + 1] = {}
          target_state = containers_by_order[#containers_by_order]
        end

        table.insert(target_state, container)
      end
    end
  end

  return vim.iter(containers_by_order):flatten()
end

---List docker containers with fzf-lua interface
---@param opts? table fzf-lua options
M.docker_containers = function(opts)
  opts = opts or {}

  -- Get all containers (running and stopped)
  docker_exec({ 'ps', '-a', '--format', 'json' }, function(output)
    local containers = sort_containers_by_state(output, { "running", "restarting", "created", "exited" })

    -- Build the sources and a map by key
    local containers_entries, container_map = {}, {}
    for container in containers do
      local fzf_line, key = format_entry(container)
      table.insert(containers_entries, fzf_line)
      container_map[key] = container
    end

    if #containers_entries == 0 then
      vim.notify('No Docker containers found', vim.log.levels.WARN)
      return
    end

    -- Create fzf picker with custom actions
    -- nth tells fzf to show/search only the first 3 columns (hide the key)
    fzf.fzf_exec(containers_entries, vim.tbl_deep_extend("force", {
      prompt = "Docker Containers> ",
      fzf_opts = {
        ["--ansi"]           = true,
        ["--delimiter"]      = "\t",
        ["--with-nth"]       = "1,2,3", -- display cols only
        ["--nth"]            = "1,2,3", -- search only these cols
        ["--preview-window"] = "bottom:50%:wrap:follow",
        ["--header"]         =
        "Enter: logs/start | C-s: start | C-q: stop | C-c: stop prefix | C-d: delete prefix | C-l: logs | C-b: buf log | C-t: shell | C-x: stats",
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

          local escaped = utils.safe_pattern(q)
          for _, c in pairs(container_map) do
            if c.State ~= "running" and c.State ~= "restarting" and c.Names:match("^" .. escaped) then
              container_action(c.ID, "remove")
            end
          end
        end,
        ["ctrl-l"] = function(selected)
          local c = container_map[extract_key(selected[1]) or ""]
          if c then container_action(c.ID, "logs") end
        end,
        ["ctrl-b"] = function(selected)
          local c = container_map[extract_key(selected[1]) or ""]
          if c then container_action(c.ID, "logs_buf") end
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
          local escaped = utils.safe_pattern(q)
          for _, c in pairs(container_map) do
            if c.State ~= "running" and c.State ~= "restarting" and c.Names:match("^" .. escaped) then
              container_action(c.ID, "start")
            end
          end
        end,
        ["ctrl-c"] = function(_, args)
          local q = args and args.query and vim.trim(args.query) or ""
          if q == "" then return end
          local escaped = utils.safe_pattern(q)
          for _, c in pairs(container_map) do
            if (c.State == "running" or c.State == "restarting") and c.Names:match("^" .. escaped) then
              container_action(c.ID, "stop")
            end
          end
        end,
      },
    }, opts))
  end)
end

return M
