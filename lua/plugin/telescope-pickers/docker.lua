local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values
local entry_display = require("telescope.pickers.entry_display")

local Job = require "plenary.job"

local log = require 'plenary.log'.new({})
log.level = 'info'

local M = {}

M.settings = {}

M.setup = function(opts)
  opts = opts or {}
  M.settings.tmux = opts.tmux or false
end

---Verify if tmux is running
---@return boolean
local function _verify_tmux()
  local tmux_running = false
  if vim.fn.executable 'tmux' == 1 then
    vim.cmd('silent !tmux info')
    log.debug('[TMUX] shell_error: ', vim.v.shell_error)
    tmux_running = vim.v.shell_error == 0
  end

  return tmux_running
end

---Open a terminal window or tmux pane depending on the settings
---@param command table
---@param args string
---@param insert boolean
local function _tmux_or_termopen(command, args, insert)
  local tmux_running = _verify_tmux()
  if vim.fn.executable 'tmux' == 1 then
    vim.system { 'tmux', 'info' }:wait()
    tmux_running = vim.v.shell_error == 0
  end

  log.debug('[TERM] tmux_running: ', tmux_running)

  if M.settings.tmux and tmux_running then
    table.insert(command, 1, args)
    table.insert(command, 1, 'tmux')
    log.debug('[LOGS] command', vim.fn.join(command, ' '))

    vim.fn.system(vim.fn.join(command, ' '))
  else
    if M.settings.tmux then
      if args == 'new-window' then
        args = 'enew!'
      else
        args = 'vnew!'
      end
      insert = true
    end
    log.debug('[LOGS] command', vim.fn.join(command, ' '))
    vim.cmd('silent ' .. args)

    vim.fn.jobstart(command, {
      stdout_buffered = true,
    })
    vim.cmd.normal('G')

    if insert then
      vim.cmd 'startinsert'
    end
  end
end

-- Display settings
local displayer = entry_display.create {
  separator = " ",
  items = {
    { width = 25 },
    { width = 25 },
    { width = 40 },
  },
}

---Assigns a highlight group based on the status of the container
---@param status string
---@return string
local highlight_status = function(status)
  if status:find('Up') then
    return 'DiagnosticHint'
  elseif status:find('Exited') then
    return 'TelescopeResultsNumber'
  elseif status:find('Created') then
    return 'DiagnosticWarn'
  else
    return 'TelescopeResults'
  end
end

---Make the display for the container
---@param entry table
---@return string
local make_display = function(entry)
  ---@diagnostic disable-next-line: redundant-return-value
  return displayer {
    { entry.value.Names },
    { entry.value.Image,  'TelescopeResultsIdentifier' },
    { entry.value.Status, highlight_status(entry.value.Status) },
  }
end

---Main function to list docker containers
---@param opts table
M.docker_containers = function(opts)
  opts = opts or {}
  M.setup(opts)

  local default_opts = {
    prompt_title = "Docker Containers",
    previewer = true,
    layout_strategy = "bottom_pane",
    sorting_strategy = "ascending",
  }

  opts = vim.tbl_deep_extend("force", default_opts, opts)

  pickers.new(opts, {
    finder = finders.new_async_job {
      command_generator = function()
        return { "docker", "ps", "-a", "--format", "json" }
      end,
      entry_maker = function(entry)
        local parsed = vim.json.decode(entry)
        return {
          value = parsed,
          display = make_display,
          ordinal = parsed.Names,
        }
      end,
    },
    previewer = previewers.new_buffer_previewer {
      define_preview = function(self, entry)
        local preview = {}
        if entry.value.State ~= "running" then
          preview = vim.iter(vim.split(vim.inspect(entry.value), '\n')):flatten():totable()
        else
          local logs = vim.fn.systemlist({ 'docker', 'logs', entry.value.ID, '--tail', "50" })
          preview = logs
        end
        if not vim.api.nvim_buf_is_valid(self.state.bufnr) or not vim.api.nvim_win_is_valid(self.state.winid) then
          return
        end
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, preview)
      end,
    },
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      local refresh_picker = function()
        local ok, picker = pcall(action_state.get_current_picker, prompt_bufnr)
        if not ok or not picker then
          return
        end
        picker:refresh()
      end

      local function start_container(_, container)
        local selection = action_state.get_selected_entry()
        if not selection then
          return
        end

        local container_id = selection.value.ID
        if container then
          container_id = container
        end

        local command = 'docker'
        local args = { 'start', container_id }

        log.debug('[START] container_id: ', container_id)
        ---@diagnostic disable-next-line: missing-fields
        Job:new {
          command = command,
          args = args,
          on_exit = refresh_picker,
        }:start()
      end

      local function stop_container(_, container)
        local selection = action_state.get_selected_entry()
        if not selection then
          return
        end

        local container_id = selection.value.ID

        if container then
          log.debug('[STOP] Container found, replacing container_id')
          log.debug('[STOP] container_id: ', container_id)
          container_id = container
          log.debug('[STOP] container_id: ', container_id)
        end

        local command = 'docker'
        local args = { 'stop', container_id }

        log.debug('[STOP] container_id: ', container_id)
        ---@diagnostic disable-next-line: missing-fields
        Job:new {
          command = command,
          args = args,
          on_exit = refresh_picker,
        }:start()
      end

      local function delete_container(_, container)
        local selection = action_state.get_selected_entry()
        if not selection then
          return
        end

        local container_id = selection.value.ID

        if container then
          log.debug('[DELETE] Container found, replacing container_id')
          log.debug('[DELETE] container_id: ', container_id)
          container_id = container
          log.debug('[DELETE] container_id: ', container_id)
        end

        local command = 'docker'
        local args = { 'rm', container_id }

        log.debug('[DELETE] container_id: ', container_id)
        ---@diagnostic disable-next-line: missing-fields
        Job:new {
          command = command,
          args = args,
          on_exit = refresh_picker,
        }:start()
      end

      local function open_log(_, new_window)
        local selection = action_state.get_selected_entry()
        if not selection then
          log.debug('No selection found')
          return
        end
        local container_id = selection.value.ID

        local args = ''

        if new_window then
          args = M.settings.tmux and 'new-window' or 'enew!'
        else
          args = M.settings.tmux and 'split-window -h' or 'vnew!'
        end

        local command = {
          'docker',
          'logs',
          container_id,
          '-f'
        }

        _tmux_or_termopen(command, args, false)
      end

      local function handle_prefix(_, action)
        local selection = action_state.get_selected_entry()
        if not selection or not vim.api.nvim_buf_is_valid(prompt_bufnr) then
          return
        end

        local prefix = vim.fn.split(vim.api.nvim_buf_get_lines(prompt_bufnr, 0, 1, false)[1], ' ')[2]
        if prefix == nil then
          return
        end

        log.debug('prefix: ', prefix)

        local picker = action_state.get_current_picker(prompt_bufnr)
        local elements = picker.manager.linked_states.head
        local element = elements

        -- Escape prefix for regex
        prefix = prefix:gsub('%-', '%%-')

        -- Loop through all elements in the results
        while true do
          log.debug('element: ', vim.inspect(element.item[1].ordinal))
          local item = element.item[1]

          if item ~= nil and item.value ~= nil and item.value.Names ~= nil and item.value.Names:match('^' .. prefix .. '.*') then
            if action == 'start' then
              start_container(_, item.value.ID)
            elseif action == 'close' then
              stop_container(_, item.value.ID)
            elseif action == 'delete' then
              delete_container(_, item.value.ID)
            end
          end
          if element.next == nil then
            break
          end
          element = element.next
        end
      end

      local function log_to_buf()
        local selection = action_state.get_selected_entry()
        if not selection then
          return
        end

        actions.close(prompt_bufnr)

        local container_id = selection.value.ID

        log.debug('[LOGS] container_id: ', container_id)
        local logs = vim.fn.systemlist({ 'docker', 'logs', container_id })

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, logs)
        vim.api.nvim_set_current_buf(buf)
      end

      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        if not selection then
          return
        end

        if selection.value.State == 'running' then
          log.debug('Container ' .. selection.value.Names .. ' is running, opening logs')
          open_log(_, false)
        else
          log.debug('Container ' .. selection.value.Names .. ' is not running, starting container')
          start_container()
        end
      end)

      -- Naming functions
      local function open_log_in_new_window()
        open_log(_, true)
      end

      local function open_log_in_split()
        open_log(_, false)
      end

      local function prefix_action_start()
        handle_prefix(_, 'start')
      end

      local function prefix_action_close()
        handle_prefix(_, 'close')
      end

      local function prefix_action_delete()
        local prefix = vim.fn.split(vim.api.nvim_buf_get_lines(prompt_bufnr, 0, 1, false)[1], ' ')[2]
        if prefix == nil then
          return
        end

        local confirm = vim.fn.confirm('Are you sure you want to delete containers with prefix "' .. prefix .. '"?',
          '&Yes\n&No', 2)
        if confirm == 2 then
          return
        end

        handle_prefix(_, 'delete')
      end

      local function delete_this_container()
        local confirm = vim.fn.confirm('Are you sure you want to delete this container?', '&Yes\n&No', 2)
        if confirm == 2 then
          return
        end
        delete_container()
      end

      local function init_terminal()
        local selection = action_state.get_selected_entry()
        if not selection then
          return
        end
        local container_id = selection.value.ID
        local state = selection.value.State

        if state ~= 'running' then
          start_container()
        end

        local tmux_running = _verify_tmux()

        local args = tmux_running and M.settings.tmux and 'split-window -h' or 'vnew!'

        local command = {
          'docker',
          'exec',
          '-it',
          container_id,
          'bash'
        }

        _tmux_or_termopen(command, args, true)
      end

      local function container_stats()
        local selection = action_state.get_selected_entry()
        if not selection then
          return
        end
        local container_id = selection.value.ID
        local state = selection.value.State

        if state ~= 'running' then
          start_container()
          return
        end

        local tmux_running = _verify_tmux()

        local args = tmux_running and M.settings.tmux and 'split-window -h' or 'vnew!'

        local command = {
          'docker',
          'stats',
          container_id
        }

        _tmux_or_termopen(command, args, false)
      end

      map('i', '<C-o>', start_container)
      map('n', '+', start_container)
      map('i', '<C-q>', stop_container)
      map('n', '-', stop_container)
      map('i', '<C-l>', open_log_in_new_window)
      map('n', 'L', open_log_in_new_window)
      map('i', '<C-h>', open_log_in_split)
      map('i', '<C-b>', log_to_buf)
      map('n', 'b', log_to_buf)
      map('i', '<C-r>', prefix_action_start)
      map('n', 'r', prefix_action_start)
      map({ 'i', 'n' }, '<C-d>', delete_this_container)
      map({ 'i', 'n' }, '<C-c>', prefix_action_close)
      map({ 'i', 'n' }, '<C-k>', prefix_action_delete)
      map('n', 't', init_terminal)
      map('i', '<C-t>', init_terminal)
      map('n', 's', container_stats)
      map('i', '<C-s>', container_stats)

      return true
    end,
  }):find()
end
return M
