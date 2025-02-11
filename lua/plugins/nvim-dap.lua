return {
  'mfussenegger/nvim-dap',
  dependencies = {
    'mfussenegger/nvim-dap-python',
    "leoluz/nvim-dap-go",
    "rcarriga/nvim-dap-ui",
    'nvim-neotest/nvim-nio',
    'williamboman/mason.nvim',
    'jbyuki/one-small-step-for-vimkind',
    'theHamsta/nvim-dap-virtual-text',
  },
  config = function()
    local dap = require('dap')
    local dap_ui = require('dapui')
    local dap_python = require('dap-python')

    dap_ui.setup()
    require('dap-go').setup()
    require('nvim-dap-virtual-text').setup()

    dap.configurations.python = {
      {
        name = 'Launch Django debugging in Docker',
        type = 'python',
        request = 'attach',
        pathMappings = {
          {
            localRoot = '${workspaceFolder}/app',
            remoteRoot = '/usr/src/app',
          },
        },
        port = 5678,
        host = '127.0.0.1',
        django = true,
      },
    }
    dap_python.setup(vim.fs.joinpath(vim.fn.stdpath('config'), '.venv', 'bin', 'python'), { include_configs = true })

    dap.configurations.lua = {
      {
        type = 'nlua',
        request = 'attach',
        name = 'Attach to running Neovim instance',
      }
    }

    dap.adapters.nlua = function(callback, config)
      callback({ type = 'server', host = '127.0.0.1', port = 8086 })
    end

    -- Keymaps
    local keymap = vim.keymap.set
    -- Start debugging
    keymap('n', '<leader>db', dap.toggle_breakpoint, { silent = true, desc = 'Toggle breakpoint' })
    keymap('n', '<leader>dr', dap.step_back, { silent = true, desc = 'Step back' })
    keymap('n', '<F3>', dap.step_into, { silent = true, desc = 'Step into' })
    keymap('n', '<F4>', dap.step_over, { silent = true, desc = 'Step over' })
    keymap('n', '<F5>', dap.continue, { silent = true, desc = 'Continue' })
    keymap('n', '<F6>', dap.step_out, { silent = true, desc = 'Step out' })
    keymap('n', '<F12>', dap.restart, { silent = true, desc = 'Restart' })
    keymap('n', '<leader>dl', dap.run_last, { silent = true, desc = 'Run last' })

    vim.keymap.set('n', '<leader>dl', function()
      require "osv".launch({ port = 8086 })
    end, { noremap = true, desc = 'Debug Lua' })

    vim.keymap.set('n', '<leader>dw', function()
      local widgets = require "dap.ui.widgets"
      widgets.hover()
    end, { noremap = true, desc = 'Show hover' })

    vim.keymap.set('n', '<leader>df', function()
      local widgets = require "dap.ui.widgets"
      widgets.centered_float(widgets.frames)
    end, { noremap = true, desc = 'Show frames' })

    -- Debugging UI
    keymap('n', '<leader>du', dap_ui.toggle, { silent = true, desc = 'Toggle UI' })
    keymap('n', '<leader>dh', function()
      require('dapui').eval(nil, { enter = true })
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
