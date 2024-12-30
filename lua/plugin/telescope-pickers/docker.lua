local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values

local log = require 'plenary.log'.new({})
log.level = 'info'

local M = {}

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
               display = parsed.Status .. '\t\t\t' .. parsed.Names,
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
               local logs = vim.fn.systemlist({ 'docker', 'logs', entry.value.ID })
               preview = logs
            end
            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, preview)
         end,
      },
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
         local function start_container(container)
            local selection = action_state.get_selected_entry()
            if not selection then
               return
            end

            local container_id = selection.value.ID
            if container then
               container_id = container
            end

            local command = { 'docker', 'start', container_id }
            vim.fn.system(vim.fn.join(command, ' '))

            local picker = action_state.get_current_picker(prompt_bufnr)
            picker:refresh()
            picker:refresh_previewer()
         end

         local function stop_container(container)
            local selection = action_state.get_selected_entry()
            if not selection then
               return
            end

            local container_id = selection.value.ID

            if container then
               container_id = container
            end

            local command = { 'docker', 'stop', container_id }
            vim.fn.system(vim.fn.join(command, ' '))

            local picker = action_state.get_current_picker(prompt_bufnr)
            picker:refresh()
            picker:refresh_previewer()
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
               arg = 'new-window'
            else
               arg = 'split-window -h'
            end

            local command = {
               'tmux',
               arg,
               'docker',
               'logs',
               container_id,
               '-f'
            }

            log.debug('command: ', vim.fn.join(command, ' '))
            vim.fn.system(vim.fn.join(command, ' '))
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
            local element= elements

            -- Loop through all elements in the results
            while element.next ~= nil do
               log.debug('element: ', vim.inspect(element.item[1].ordinal))
               local item = element.item[1]
               if item ~= nil and item.ordinal ~= nil and item.ordinal:match('^' .. prefix) then
                  if action == 'start' then
                     log.info('start container: ', item.value.ID)
                     start_container(item.value.ID)
                  elseif action == 'close' then
                     log.info('close container: ', item.ordinal)
                     stop_container(item.value.ID)
                  end
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

         map('i', '<C-o>', start_container)
         map('n', '+', start_container)
         map('i', '<C-c>', stop_container)
         map('n', '-', stop_container)
         map('i', '<C-l>', function() open_log(_, true) end)
         map('n', 'l', function() open_log(_, true) end)
         map('i', '<C-h>', function() open_log(_, false) end)
         map('i', '<C-b>', log_to_buf)
         map('n', 'b', log_to_buf)
         map('i', '<C-q>', function() handle_prefix(_, 'close') end)
         map('n', 'q', function() handle_prefix(_, 'close') end)
         map('i', '<C-r>', function() handle_prefix(_, 'start') end)
         map('n', 'r', function() handle_prefix(_, 'start') end)
         return true
      end,
   }):find()
end

return M
