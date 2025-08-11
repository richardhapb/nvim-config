local lsp_utils = require 'functions.lsp'

return {
  'mfussenegger/nvim-dap',
  dependencies = {
    'mfussenegger/nvim-dap-python',
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
    require('nvim-dap-virtual-text').setup({})

    dap.configurations.python = {
      {
        name = 'Project',
        request = 'launch',
        type = 'debugpy',
        program = "${workspaceFolder}/main.py",
        cwd = "${workspaceFolder}",
        python = lsp_utils.search_python_path,
        justMyCode = true,
      },
      {
        name = 'Launch Django debugging in Docker',
        type = 'debugpy',
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
        env = {
          PYTHONASYNCIODEBUG = 1
        }
      },
      {
        name = 'Launch Django debugging staging',
        type = 'debugpy',
        request = 'attach',
        pathMappings = {
          {
            localRoot = '${workspaceFolder}/app',
            remoteRoot = '/home/app/web/',
          },
        },
        port = 5678,
        host = vim.env.HOST_STAGING,
        django = true,
        justMyCode = false,
        subProcess = true,
        env = {
          PYDEVD_DISABLE_FILE_VALIDATION = "1",
          ALLOWED_HOSTS = "*",
          DJANGO_DEBUG = "True",
        }
      },
    }

    dap_python.test_runner = "pytest"
    dap_python.resolve_python = lsp_utils.search_python_path

    dap_python.setup(vim.fs.joinpath(vim.fn.stdpath('config'), '.venv', 'bin', 'python'), {})

    dap.configurations.lua = {
      {
        type = 'nlua',
        request = 'attach',
        name = 'Attach to running Neovim instance',
      }
    }

    dap.adapters.nlua = function(callback, _)
      callback({ type = 'server', host = '127.0.0.1', port = 8086 })
    end

    local BASH_DEBUG_ADAPTER_BIN = vim.fs.joinpath(vim.fn.stdpath('data'), "mason", "bin", "bash-debug-adapter")
    local BASHDB_DIR = vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "packages", "bash-debug-adapter", "extension",
      "bashdb_dir")

    dap.adapters.sh = {
      type = "executable",
      command = BASH_DEBUG_ADAPTER_BIN,
    }
    dap.configurations.sh = {
      {
        name = "Launch Bash debugger",
        type = "sh",
        request = "launch",
        program = "${file}",
        cwd = "${fileDirname}",
        pathBashdb = BASHDB_DIR .. "/bashdb",
        pathBashdbLib = BASHDB_DIR,
        pathBash = "bash",
        pathCat = "cat",
        pathMkfifo = "mkfifo",
        pathPkill = "pkill",
        env = {},
        args = {},
        -- showDebugOutput = true,
        -- trace = true,
      }
    }

    dap.set_log_level("DEBUG")

    -- Keymaps
    local keymap = vim.keymap.set
    -- Start debugging
    keymap('n', '<leader>db', dap.toggle_breakpoint, { silent = true, desc = 'Toggle breakpoint' })
    keymap('n', '<leader>dB', function()
      local condition = vim.fn.input("Breakpoint condition: ")
      if condition ~= nil and condition ~= "" then
        dap.toggle_breakpoint(condition)
      end
    end, { silent = true, desc = 'Conditional breakpoint' })
    keymap('n', '<leader>dr', dap.step_back, { silent = true, desc = 'Step back' })
    keymap('n', '<F3>', dap.step_into, { silent = true, desc = 'Step into' })
    keymap('n', '<F4>', dap.step_over, { silent = true, desc = 'Step over' })
    keymap('n', '<F5>', dap.continue, { silent = true, desc = 'Continue' })
    keymap('n', '<F6>', dap.step_out, { silent = true, desc = 'Step out' })
    keymap('n', '<F12>', dap.restart, { silent = true, desc = 'Restart' })
    keymap('n', '<leader>d0', dap.run_last, { silent = true, desc = 'Run last' })

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
    keymap('n', '<leader>dc', function() dap_python.test_class { config = { justMyCode = false } } end,
      { silent = true, desc = 'Test class' })

    dap.listeners.before.attach.dapui_config = function()
      dap_ui.open()
    end
    dap.listeners.before.launch.dapui_config = function()
      dap_ui.open()
    end
    -- dap.listeners.before.event_terminated.dapui_config = function()
    --   dap_ui.close()
    -- end
    -- dap.listeners.before.event_exited.dapui_config = function()
    --   dap_ui.close()
    -- end
  end,
}
