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

  -- Jupyter
  use 'jpalardy/vim-slime'
  use "willothy/wezterm.nvim"
  use {
    "benlubas/molten-nvim",
    run = ":UpdateRemotePlugins",  -- Equivalente a `build = ":UpdateRemotePlugins"`
    config = function()
        -- Configuración personalizada para molten-nvim
        vim.g.molten_output_win_max_height = 12
        -- I find auto open annoying, keep in mind setting this option will require setting
        -- a keybind for `:noautocmd MoltenEnterOutput` to open the output again
        vim.g.molten_auto_open_output = false

        -- this guide will be using image.nvim
        -- Don't forget to setup and install the plugin if you want to view image outputs
        vim.g.molten_image_provider = "wezterm.nvim"

        -- optional, I like wrapping. works for virt text and the output window
        vim.g.molten_wrap_output = true

        -- Output as virtual text. Allows outputs to always be shown, works with images, but can
        -- be buggy with longer images
        vim.g.molten_virt_text_output = true

        -- this will make it so the output shows up below the \`\`\` cell delimiter
        vim.g.molten_virt_lines_off_by_1 = true
    end,
  }
  use {
    "quarto-dev/quarto-nvim",
    requires = {
      "jmbuhr/otter.nvim",
      "nvim-treesitter/nvim-treesitter"
    },
    config = function()
        require("quarto").setup({
            lspFeatures = {
                languages = { "r", "python", "rust" },
                chunks = "all",
                diagnostics = {
                    enabled = true,
                    triggers = { "BufWritePost" },
                },
                completion = {
                    enabled = true,
                },
            },
            codeRunner = {
                enabled = true,
                default_method = "molten",
            },
        })
    end,
  }
  use "GCBallesteros/jupytext.nvim"
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
    vim.api.nvim_set_keymap('n', 's', api.node.open.horizontal, opts('Open: Horizontal Split'))
    vim.api.nvim_set_keymap('n', 'v', api.node.open.vertical, opts('Open: Vertical Split'))
    vim.api.nvim_set_keymap('n', '<CR>', api.node.open.edit, opts('Open: In Same Window'))
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
vim.api.nvim_set_keymap("n", "<leader>mi", ":MoltenInit<CR>", { silent = true, desc = "Initialize the plugin" })
vim.api.nvim_set_keymap("n", "<leader>me", ":MoltenEvaluateOperator<CR>", { silent = true, desc = "run operator selection" })
vim.api.nvim_set_keymap("n", "<leader>ml", ":MoltenEvaluateLine<CR>", { silent = true, desc = "evaluate line" })
vim.api.nvim_set_keymap("n", "<leader>mr", ":MoltenReevaluateCell<CR>", { silent = true, desc = "re-evaluate cell" })
vim.api.nvim_set_keymap("v", "<leader>mr", ":<C-u>MoltenEvaluateVisual<CR>gv", { silent = true, desc = "evaluate visual selection" })
vim.api.nvim_set_keymap("n", "<leader>md", ":MoltenDelete<CR>", { silent = true, desc = "molten delete cell" })
vim.api.nvim_set_keymap("n", "<leader>mh", ":MoltenHideOutput<CR>", { silent = true, desc = "hide output" })
vim.api.nvim_set_keymap("n", "<leader>ms", ":noautocmd MoltenEnterOutput<CR>", { silent = true, desc = "show/enter output" })
vim.api.nvim_set_keymap('n', '<leader>b', ':Telescope buffers<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>rr', ':!python %<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('t', '<Esc>', [[<C-\><C-n>]], { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>w', ':bd<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>e', ':NvimTreeToggle<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('i', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>rc", "<cmd>lua require('quarto.runner').run_cell()<CR>", { desc = "run cell", silent = true })
vim.api.nvim_set_keymap("n", "<leader>ra", "<cmd>lua require('quarto.runner').run_above()<CR>", { desc = "run cell and above", silent = true })
vim.api.nvim_set_keymap("n", "<leader>rA", "<cmd>lua require('quarto.runner').run_all()<CR>", { desc = "run all cells", silent = true })
vim.api.nvim_set_keymap("n", "<leader>rl", "<cmd>lua require('quarto.runner').run_line()<CR>", { desc = "run line", silent = true })
vim.api.nvim_set_keymap("v", "<leader>rp", "<cmd>lua require('quarto.runner').run_range()<CR>", { desc = "run visual range", silent = true })
vim.api.nvim_set_keymap("n", "<leader>RA", "<cmd>lua require('quarto.runner').run_all(true)<CR>", { desc = "run all cells of all languages", silent = true })

require("jupytext").setup({
    style = "markdown",
    output_extension = "md",
    force_ft = "markdown",
})

require("nvim-treesitter.configs").setup({
    ensure_installed = { "python", "markdown" },
    highlight = { enable = true },
    textobjects = {
        select = {
            enable = true,
            keymaps = {
                ["ib"] = "@code_cell.inner",
                ["ab"] = "@code_cell.outer",
            },
        },
        move = {
            enable = true,
            set_jumps = true,
            goto_next_start = {
                ["]b"] = "@code_cell.outer",
            },
            goto_previous_start = {
                ["[b"] = "@code_cell.outer",
            },
        },
    },
})

vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = { "*.ipynb" },
    callback = function()
        if require("molten.status").initialized() == "Molten" then
            vim.cmd("MoltenExportOutput!")
        end
    end,
})


require("nvim-treesitter.configs").setup({
    -- ... other ts config
    textobjects = {
        move = {
            enable = true,
            set_jumps = false, -- you can change this if you want.
            goto_next_start = {
                --- ... other keymaps
                ["]b"] = { query = "@code_cell.inner", desc = "next code block" },
            },
            goto_previous_start = {
                --- ... other keymaps
                ["[b"] = { query = "@code_cell.inner", desc = "previous code block" },
            },
        },
        select = {
            enable = true,
            lookahead = true, -- you can change this if you want
            keymaps = {
                --- ... other keymaps
                ["ib"] = { query = "@code_cell.inner", desc = "in block" },
                ["ab"] = { query = "@code_cell.outer", desc = "around block" },
            },
        },
        swap = { -- Swap only works with code blocks that are under the same
                 -- markdown header
            enable = true,
            swap_next = {
                --- ... other keymap
                ["<leader>sbl"] = "@code_cell.outer",
            },
            swap_previous = {
                --- ... other keymap
                ["<leader>sbh"] = "@code_cell.outer",
            },
        },
    }
})

require("lspconfig")["pyright"].setup({
    on_attach = on_attach,
    capabilities = capabilities,
    settings = {
        python = {
            analysis = {
                diagnosticSeverityOverrides = {
                    reportUnusedExpression = "none",
                },
            },
        },
    },
})

-- automatically import output chunks from a jupyter notebook
-- tries to find a kernel that matches the kernel in the jupyter notebook
-- falls back to a kernel that matches the name of the active venv (if any)
local imb = function(e) -- init molten buffer
    vim.schedule(function()
        local kernels = vim.fn.MoltenAvailableKernels()
        local try_kernel_name = function()
            local metadata = vim.json.decode(io.open(e.file, "r"):read("a"))["metadata"]
            return metadata.kernelspec.name
        end
        local ok, kernel_name = pcall(try_kernel_name)
        if not ok or not vim.tbl_contains(kernels, kernel_name) then
            kernel_name = nil
            local venv = os.getenv("VIRTUAL_ENV") or os.getenv("CONDA_PREFIX")
            if venv ~= nil then
                kernel_name = string.match(venv, "/.+/(.+)")
            end
        end
        if kernel_name ~= nil and vim.tbl_contains(kernels, kernel_name) then
            vim.cmd(("MoltenInit %s"):format(kernel_name))
        end
        vim.cmd("MoltenImportOutput")
    end)
end

-- automatically import output chunks from a jupyter notebook
vim.api.nvim_create_autocmd("BufAdd", {
    pattern = { "*.ipynb" },
    callback = imb,
})

-- we have to do this as well so that we catch files opened like nvim ./hi.ipynb
vim.api.nvim_create_autocmd("BufEnter", {
    pattern = { "*.ipynb" },
    callback = function(e)
        if vim.api.nvim_get_vvar("vim_did_enter") ~= 1 then
            imb(e)
        end
    end,
})
-- automatically export output chunks to a jupyter notebook on write
vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = { "*.ipynb" },
    callback = function()
        if require("molten.status").initialized() == "Molten" then
            vim.cmd("MoltenExportOutput!")
        end
    end,
})
