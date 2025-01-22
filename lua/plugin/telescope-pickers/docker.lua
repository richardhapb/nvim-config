local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values

local Job = require "plenary.job"

local log = require 'plenary.log'.new({})
log.level = 'info'

local M = {}

M.settings = {
   tmux = false
}

M.setup = function()
end

local function _tmux_or_termopen(command, arg, insert)
   if insert == nil then
      insert = false 
   end
   log.debug('[LOGS] command', vim.fn.join(command, ' '))
   if M.settings.tmux then
      vim.cmd('silent ' .. arg)

      vim.fn.termopen(vim.fn.join(command, ' '))
      vim.cmd.normal('G')
   else
      table.insert(command, 1, arg)
      table.insert(command, 1, 'tmux')
      vim.fn.system(vim.fn.join(command, ' '))
   end
   if insert then
      vim.cmd 'startinsert'
   end
end

M.docker_containers = function()
   pickers.new({}, {
      prompt_title = "Docker Containers",
      finder = finders.new_async_job {
         command_generator = function()
            return { "docker", "ps", "-a", "--format", "json" }
         end,
         entry_maker = function(entry)
            local parsed = vim.json.decode(entry)
            return {
               value = parsed,
               display = parsed.Names .. '\t\t\t' .. parsed.Status,
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
            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, preview)
         end,
      },
      sorter = conf.generic_sorter({}),
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
               return
            end
            local container_id = selection.value.ID
            local state = selection.value.State

            if state ~= 'running' then
               start_container()
               return
            end

            local arg = ''

            if new_window then
               arg = M.settings.tmux and 'new-window' or 'enew'
            else
               arg = M.settings.tmux and 'split-window -h' or 'vnew'
            end

            local command = {
               'docker',
               'logs',
               container_id,
               '-f'
            }

            _tmux_or_termopen(command, arg, false)
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

            if selection.value.State ~= 'running' then
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

            local arg = M.settings.tmux and 'split-window -h' or 'vnew'

            local command = {
               'docker',
               'exec',
               '-it',
               container_id,
               'bash'
            }

            _tmux_or_termopen(command, arg, true)
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

            local arg = M.settings.tmux and 'split-window -h' or 'vnew'

            local command = {
               'docker',
               'stats',
               container_id
            }

            _tmux_or_termopen(command, arg, false)
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

