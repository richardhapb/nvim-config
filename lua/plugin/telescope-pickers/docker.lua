local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values

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
         local function start_container()
            local selection = action_state.get_selected_entry()
            if not selection then
               return
            end

            local container_id = selection.value.ID
            local command = { 'docker', 'start', container_id }
            vim.fn.system(vim.fn.join(command, ' '))
            vim.api.nvim_buf_set_lines(prompt_bufnr, 0, -1, false, { '' })
         end

         local function stop_container()
            local selection = action_state.get_selected_entry()
            if not selection then
               return
            end

            local container_id = selection.value.ID
            local command = { 'docker', 'stop', container_id }
            vim.fn.system(vim.fn.join(command, ' '))
            vim.api.nvim_buf_set_lines(prompt_bufnr, 0, -1, false, { '' })
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

            vim.fn.system(vim.fn.join(command, ' '))
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
               open_log(_, false)
            else
               start_container()
            end
         end)

         map('i', '<C-o>', start_container)
         map('n', '+', start_container)
         map('i', '<C-c>', stop_container)
         map('n', '-', stop_container)
         map('i', '<C-l>', function () open_log(_, true) end)
         map('n', 'l', function () open_log(_, true) end)
         map('i', '<C-h>', function () open_log(_, false) end)
         map('i', '<C-b>', log_to_buf)
         map('n', 'b', log_to_buf)
         return true
      end,


   }):find()
end

M.docker_containers()

return M
