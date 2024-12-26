return {
   'mfussenegger/nvim-dap',
   dependencies = {
      'mfussenegger/nvim-dap-python',
      "leoluz/nvim-dap-go",
      "rcarriga/nvim-dap-ui",
      'nvim-neotest/nvim-nio',
      'williamboman/mason.nvim',
   },
   config = function()
      local dap = require('dap')
      local dap_ui = require('dapui')
      local dap_python = require('dap-python')

      dap_ui.setup()
      require('dap-go').setup()

      dap_python.setup(vim.fn.stdpath('config') .. '/.venv/bin/python')

      -- Keymaps
      local keymap = vim.keymap.set
      -- Start debugging
      keymap('n', '<F1>', dap.toggle_breakpoint, {silent = true, desc = 'Toggle breakpoint' })
      keymap('n', '<F2>', dap.step_back, { silent = true, desc = 'Step back' })
      keymap('n', '<F3>', dap.step_over, { silent = true, desc = 'Step over' })
      keymap('n', '<F4>', dap.step_into, { silent = true, desc = 'Step into' })
      keymap('n', '<F5>', dap.continue, { silent = true, desc = 'Continue' })
      keymap('n', '<F6>', dap.run_last, { silent = true, desc = 'Run last' })
      keymap('n', '<F7>', dap.step_out, { silent = true, desc = 'Step out' })
      keymap('n', '<F12>', dap.restart, { silent = true, desc = 'Restart' })

      -- Debugging UI
      keymap('n', '<leader>du', dap_ui.toggle, { silent = true, desc = 'Toggle UI' })
      keymap('n', '<leader>dh', function()
         require('dapui').eval(nil, {enter = true})
      end, { silent = true, desc = 'Evaluate expression' })

      -- Python specific
      keymap('n', '<leader>dt', dap_python.test_method, { silent = true, desc = 'Test method' })
      keymap('n', '<leader>df', dap_python.test_class, { silent = true, desc = 'Test class' })

      dap.listeners.before.attach.dapui_config = function()
         dap_ui.open()
      end
      dap.listeners.before.launch.dapui_config = function()
         dap_ui.open()
      end
      dap.listeners.before.event_terminated.dapui_config = function()
         dap_ui.close()
      end
      dap.listeners.before.event_exited.dapui_config = function()
         dap_ui.close()
      end
   end,
}
