-- Activar números relativos
vim.opt.number = true
vim.opt.relativenumber = true

-- Usar espacios en lugar de tabs y setear el tamaño de la indentación
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4

-- Resaltado de sintaxis
vim.cmd('syntax on')
vim.opt.termguicolors = true


vim.g.mapleader = ' '


-- Usa packer.nvim como gestor de plugins
require('packer').startup(function(use)
  -- Packer se maneja a sí mismo
  use 'wbthomason/packer.nvim'

  -- Plugins de calidad de vida
  use 'nvim-lua/plenary.nvim'
  use 'nvim-telescope/telescope.nvim'
  use 'nvim-treesitter/nvim-treesitter'

  -- LSP y autocompletado
  use 'neovim/nvim-lspconfig' -- LSP básico
  use 'williamboman/mason.nvim' -- Instalador de LSP
  use 'williamboman/mason-lspconfig.nvim' -- Conectar mason con lspconfig
  use 'hrsh7th/cmp-buffer'
  use 'L3MON4D3/LuaSnip' -- Snippets

  -- Herramientas para Python
  use 'mfussenegger/nvim-lint' -- Linters
  use 'mhartington/formatter.nvim' -- Formateo de código

  use 'kyazdani42/nvim-tree.lua'
  use 'lewis6991/gitsigns.nvim'
  use 'windwp/nvim-autopairs'
  use "folke/which-key.nvim"
  use 'kylechui/nvim-surround'
  use 'prettier/vim-prettier'
  
  -- Autocompletado
  use 'hrsh7th/nvim-cmp'                  -- Autocompletado principal
  use 'hrsh7th/cmp-nvim-lsp'              -- Fuente para LSP
  use 'hrsh7th/cmp-path'                  -- Fuente para rutas de archivos
  use 'hrsh7th/cmp-vsnip'                 -- Fuente para snippets
  use 'hrsh7th/vim-vsnip'                 -- Plugin de snippets
  use 'ray-x/lsp_signature.nvim'

  -- Debug
  use {'rcarriga/nvim-dap-ui', requires = {'mfussenegger/nvim-dap'}}
  use 'theHamsta/nvim-dap-virtual-text'
  use 'mfussenegger/nvim-dap'
  use 'nvim-neotest/nvim-nio'
end)

require'nvim-treesitter.configs'.setup {
  ensure_installed = { "python" },
  highlight = {
    enable = true,
  },
}

require('telescope').setup{
  defaults = {
    file_ignore_patterns = {"node_modules", ".git"},
  }
}

-- Atajos de teclado para Telescope
vim.api.nvim_set_keymap('n', '<leader>ff', "<cmd>Telescope find_files<cr>", { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>fg', "<cmd>Telescope live_grep<cr>", { noremap = true, silent = true })

require("mason").setup()
require("mason-lspconfig").setup({
  ensure_installed = { "pyright" },  -- Instala automáticamente el servidor para Python
})

local lspconfig = require('lspconfig')
lspconfig.pyright.setup{
  capabilities = require('cmp_nvim_lsp').default_capabilities()
}

vim.cmd [[au BufWritePost <buffer> lua require('lint').try_lint()]]

require('formatter').setup({
  logging = false,
  filetype = {
    python = {
      function()
        return {
          exe = "black",
          args = {"--fast", "-"},
          stdin = true
        }
      end
    }
  }
})
vim.api.nvim_exec([[
  augroup FormatAutogroup
    autocmd!
    autocmd BufWritePost *.py FormatWrite
  augroup END
]], true)

require('nvim-tree').setup {
  view = {
    width = 30,
    side = 'left',
  },
  renderer = {
    highlight_git = true,
    icons = {
      show = {
        git = true,
        folder = true,
        file = true,
        folder_arrow = true,
      },
    },
  },
  git = {
    enable = true,
  },
  on_attach = function(bufnr)
    local api = require('nvim-tree.api')
    local function opts(desc)
      return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
    end

    -- Define los mapeos para `split` y `vsplit`
    vim.keymap.set('n', 's', api.node.open.horizontal, opts('Open: Horizontal Split'))
    vim.keymap.set('n', 'v', api.node.open.vertical, opts('Open: Vertical Split'))
    vim.keymap.set('n', '<CR>', api.node.open.edit, opts('Open: In Same Window'))
  end,
}
-- Mapeo para abrir el árbol de archivos
vim.api.nvim_set_keymap('n', '<leader>e', ':NvimTreeToggle<CR>', { noremap = true, silent = true })

require('gitsigns').setup {
  signs = {
    add = { text = '+' },
    change = { text = '~' },
    delete = { text = '_' },
    topdelete = { text = '‾' },
    changedelete = { text = '~' },
  },
  numhl = false,
  sign_priority = 6,
  update_debounce = 200,
  status_formatter = nil,
}

-- Definimos los highlights necesarios para cada tipo de signo
vim.api.nvim_set_hl(0, 'GitSignsAdd', { link = 'GitGutterAdd' })
vim.api.nvim_set_hl(0, 'GitSignsChange', { link = 'GitGutterChange' })
vim.api.nvim_set_hl(0, 'GitSignsDelete', { link = 'GitGutterDelete' })
vim.api.nvim_set_hl(0, 'GitSignsTopdelete', { link = 'GitGutterDelete' })
vim.api.nvim_set_hl(0, 'GitSignsChangedelete', { link = 'GitGutterChange' })

require('nvim-autopairs').setup({
  check_ts = true,  -- Integración con Treesitter para un mejor análisis
})

require("which-key").setup {}
require("nvim-surround").setup({})

vim.api.nvim_set_keymap('n', '<leader>b', ':Telescope buffers<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>r', ':!python %<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('t', '<Esc>', [[<C-\><C-n>]], { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>w', ':bd<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>e', ':NvimTreeToggle<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('i', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', { noremap = true, silent = true })

vim.cmd([[
  let g:prettier#autoformat = 1
  let g:prettier#autoformat_config_present = 1
]])

-- DEBUG --
-- Configuración para nvim-cmp
local cmp = require'cmp'

cmp.setup({
  snippet = {
    expand = function(args)
      vim.fn["vsnip#anonymous"](args.body)  -- Usa vim-vsnip para expandir snippets
    end,
  },
  mapping = {
    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<C-e>'] = cmp.mapping.close(),
    ['<CR>'] = cmp.mapping.confirm({ select = true }),  -- Selecciona la primera opción con Enter
  },
  sources = cmp.config.sources({
    { name = 'nvim_lsp' },
    { name = 'vsnip' },
  }, {
    { name = 'buffer' },
    { name = 'path' }
  })
})

require "lsp_signature".setup({
  bind = true,
  hint_enable = true,
  floating_window = true,  -- Muestra una ventana flotante con los argumentos
})

local dap = require("dap")

dap.adapters.python = {
  type = "executable",
  command = ".venv/bin/python",
  args = { "-m", "debugpy.adapter" }
}

dap.configurations.python = {
  {
    type = "python",
    request = "launch",
    name = "Launch file",
    program = function()
        return vim.fn.input('Path to file: ', vim.fn.expand('%'), 'file')
    end,
    pythonPath = function()
      return ".venv/bin/python"
    end
  }
}

local dap, dapui = require("dap"), require("dapui")

dapui.setup() -- configura la UI
dap.listeners.after.event_initialized["dapui_config"] = function()
  dapui.open()
end
dap.listeners.before.event_terminated["dapui_config"] = function()
  dapui.close()
end
dap.listeners.before.event_exited["dapui_config"] = function()
  dapui.close()
end

vim.api.nvim_set_keymap("n", "<F5>", "<Cmd>lua require'dap'.continue()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<F10>", "<Cmd>lua require'dap'.step_over()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<F11>", "<Cmd>lua require'dap'.step_into()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<F12>", "<Cmd>lua require'dap'.step_out()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>b", "<Cmd>lua require'dap'.toggle_breakpoint()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>B", "<Cmd>lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>dr", "<Cmd>lua require'dap'.repl.open()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>dl", "<Cmd>lua require'dap'.run_last()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>do", "<Cmd>lua require('dapui').open()<CR>", { noremap = true, silent = true})
vim.api.nvim_set_keymap("n", "<leader>dc", "<Cmd>lua require('dapui').close()<CR>", { noremap = true, silent = true})
vim.api.nvim_set_keymap("n", "<leader>B", "<Cmd>lua require('dap').set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>", { noremap = true, silent = true })
