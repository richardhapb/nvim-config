
require('packer').startup(function(use)
    use 'wbthomason/packer.nvim'
    use {
          'folke/tokyonight.nvim',
          config = function()
              require("tokyonight").setup({
                  style = "night",              
                  transparent = true,          
                  terminal_colors = true,       
              })
              vim.cmd("colorscheme tokyonight") 
          end
      }
    use 'nvim-tree/nvim-web-devicons'      
    -- Explore
    use 'nvim-lua/plenary.nvim'
    use 'nvim-telescope/telescope.nvim'
    use 'nvim-treesitter/nvim-treesitter'
    use({
      "stevearc/oil.nvim",
      config = function()
        require("oil").setup()
      end,
    })
    use 'christoomey/vim-tmux-navigator'
    use {
      'rmagatti/goto-preview',
      config = function()
        require('goto-preview').setup {}
      end
    }
    use 'echasnovski/mini.nvim'

    -- LSP
    use 'neovim/nvim-lspconfig'
    use 'williamboman/mason.nvim' -- LSP installer
    use 'williamboman/mason-lspconfig.nvim'
    use 'hrsh7th/cmp-buffer'
    use 'L3MON4D3/LuaSnip' -- Snippets

    -- Python
    use 'mfussenegger/nvim-lint' -- Linters
    use 'mhartington/formatter.nvim' -- Code format

    use 'kyazdani42/nvim-tree.lua'
    use 'lewis6991/gitsigns.nvim'
    use 'windwp/nvim-autopairs'
    use "folke/which-key.nvim"
    use 'kylechui/nvim-surround'
    use 'prettier/vim-prettier'

    -- Autocomplete
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
          vim.g.molten_image_provider = "wezterm"

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

require("oil").setup({
  -- Oil will take over directory buffers (e.g. `vim .` or `:e src/`)
  -- Set to false if you want some other plugin (e.g. netrw) to open when you edit directories.
  default_file_explorer = true,
  -- Id is automatically added at the beginning, and name at the end
  -- See :help oil-columns
  columns = {
    "icon",
    -- "permissions",
    -- "size",
    -- "mtime",
  },
  -- Buffer-local options to use for oil buffers
  buf_options = {
    buflisted = false,
    bufhidden = "hide",
  },
  -- Window-local options to use for oil buffers
  win_options = {
    wrap = false,
    signcolumn = "no",
    cursorcolumn = false,
    foldcolumn = "0",
    spell = false,
    list = false,
    conceallevel = 3,
    concealcursor = "nvic",
  },
  -- Send deleted files to the trash instead of permanently deleting them (:help oil-trash)
  delete_to_trash = false,
  -- Skip the confirmation popup for simple operations (:help oil.skip_confirm_for_simple_edits)
  skip_confirm_for_simple_edits = false,
  -- Selecting a new/moved/renamed file or directory will prompt you to save changes first
  -- (:help prompt_save_on_select_new_entry)
  prompt_save_on_select_new_entry = true,
  -- Oil will automatically delete hidden buffers after this delay
  -- You can set the delay to false to disable cleanup entirely
  -- Note that the cleanup process only starts when none of the oil buffers are currently displayed
  cleanup_delay_ms = 2000,
  lsp_file_methods = {
    -- Enable or disable LSP file operations
    enabled = true,
    -- Time to wait for LSP file operations to complete before skipping
    timeout_ms = 1000,
    -- Set to true to autosave buffers that are updated with LSP willRenameFiles
    -- Set to "unmodified" to only save unmodified buffers
    autosave_changes = false,
  },
  -- Constrain the cursor to the editable parts of the oil buffer
  -- Set to `false` to disable, or "name" to keep it on the file names
  constrain_cursor = "editable",
  -- Set to true to watch the filesystem for changes and reload oil
  watch_for_changes = false,
  -- Keymaps in oil buffer. Can be any value that `vim.keymap.set` accepts OR a table of keymap
  -- options with a `callback` (e.g. { callback = function() ... end, desc = "", mode = "n" })
  -- Additionally, if it is a string that matches "actions.<name>",
  -- it will use the mapping at require("oil.actions").<name>
  -- Set to `false` to remove a keymap
  -- See :help oil-actions for a list of all available actions
  keymaps = {
    ["g?"] = "actions.show_help",
    ["<CR>"] = "actions.select",
    ["<C-s>"] = { "actions.select", opts = { vertical = true }, desc = "Open the entry in a vertical split" },
    ["<C-h>"] = { "actions.select", opts = { horizontal = true }, desc = "Open the entry in a horizontal split" },
    ["<C-t>"] = { "actions.select", opts = { tab = true }, desc = "Open the entry in new tab" },
    ["<C-p>"] = "actions.preview",
    ["<C-c>"] = "actions.close",
    ["<C-l>"] = "actions.refresh",
    ["-"] = "actions.parent",
    ["_"] = "actions.open_cwd",
    ["`"] = "actions.cd",
    ["~"] = { "actions.cd", opts = { scope = "tab" }, desc = ":tcd to the current oil directory", mode = "n" },
    ["gs"] = "actions.change_sort",
    ["gx"] = "actions.open_external",
    ["g."] = "actions.toggle_hidden",
    ["g\\"] = "actions.toggle_trash",
  },
  -- Set to false to disable all of the above keymaps
  use_default_keymaps = true,
  view_options = {
    -- Show files and directories that start with "."
    show_hidden = false,
    -- This function defines what is considered a "hidden" file
    is_hidden_file = function(name, bufnr)
      local m = name:match("^%.")
      return m ~= nil
    end,
    -- This function defines what will never be shown, even when `show_hidden` is set
    is_always_hidden = function(name, bufnr)
      return false
    end,
    -- Sort file names with numbers in a more intuitive order for humans.
    -- Can be "fast", true, or false. "fast" will turn it off for large directories.
    natural_order = "fast",
    -- Sort file and directory names case insensitive
    case_insensitive = false,
    sort = {
      -- sort order can be "asc" or "desc"
      -- see :help oil-columns to see which columns are sortable
      { "type", "asc" },
      { "name", "asc" },
    },
  },
  -- Extra arguments to pass to SCP when moving/copying files over SSH
  extra_scp_args = {},
  -- EXPERIMENTAL support for performing file operations with git
  git = {
    -- Return true to automatically git add/mv/rm files
    add = function(path)
      return false
    end,
    mv = function(src_path, dest_path)
      return false
    end,
    rm = function(path)
      return false
    end,
  },
  -- Configuration for the floating window in oil.open_float
  float = {
    -- Padding around the floating window
    padding = 2,
    max_width = 0,
    max_height = 0,
    border = "rounded",
    win_options = {
      winblend = 0,
    },
    -- optionally override the oil buffers window title with custom function: fun(winid: integer): string
    get_win_title = nil,
    -- preview_split: Split direction: "auto", "left", "right", "above", "below".
    preview_split = "auto",
    -- This is the config that will be passed to nvim_open_win.
    -- Change values here to customize the layout
    override = function(conf)
      return conf
    end,
  },
  -- Configuration for the file preview window
  preview_win = {
    -- Whether the preview window is automatically updated when the cursor is moved
    update_on_cursor_moved = true,
    -- Maximum file size in megabytes to preview
    max_file_size_mb = 100,
    -- Window-local options to use for preview window buffers
    win_options = {},
  },
  -- Configuration for the floating action confirmation window
  confirmation = {
    -- Width dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
    -- min_width and max_width can be a single value or a list of mixed integer/float types.
    -- max_width = {100, 0.8} means "the lesser of 100 columns or 80% of total"
    max_width = 0.9,
    -- min_width = {40, 0.4} means "the greater of 40 columns or 40% of total"
    min_width = { 40, 0.4 },
    -- optionally define an integer/float for the exact width of the preview window
    width = nil,
    -- Height dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
    -- min_height and max_height can be a single value or a list of mixed integer/float types.
    -- max_height = {80, 0.9} means "the lesser of 80 columns or 90% of total"
    max_height = 0.9,
    -- min_height = {5, 0.1} means "the greater of 5 columns or 10% of total"
    min_height = { 5, 0.1 },
    -- optionally define an integer/float for the exact height of the preview window
    height = nil,
    border = "rounded",
    win_options = {
      winblend = 0,
    },
  },
  -- Configuration for the floating progress window
  progress = {
    max_width = 0.9,
    min_width = { 40, 0.4 },
    width = nil,
    max_height = { 10, 0.9 },
    min_height = { 5, 0.1 },
    height = nil,
    border = "rounded",
    minimized_border = "none",
    win_options = {
      winblend = 0,
    },
  },
  -- Configuration for the floating SSH window
  ssh = {
    border = "rounded",
  },
  -- Configuration for the floating keymaps help window
  keymaps_help = {
    border = "rounded",
  },
})

require('goto-preview').setup {
  width = 120, -- Width of the floating window
  height = 15, -- Height of the floating window
  border = {"↖", "─" ,"┐", "│", "┘", "─", "└", "│"}, -- Border characters of the floating window
  default_mappings = false, -- Bind default mappings
  debug = false, -- Print debug information
  opacity = nil, -- 0-100 opacity level of the floating window where 100 is fully transparent.
  resizing_mappings = false, -- Binds arrow keys to resizing the floating window.
  post_open_hook = nil, -- A function taking two arguments, a buffer and a window to be ran as a hook.
  post_close_hook = nil, -- A function taking two arguments, a buffer and a window to be ran as a hook.
  references = { -- Configure the telescope UI for slowing the references cycling window.
    telescope = require("telescope.themes").get_dropdown({ hide_preview = false })
  },
  -- These two configs can also be passed down to the goto-preview definition and implementation calls for one off "peak" functionality.
  focus_on_open = true, -- Focus the floating window when opening it.
  dismiss_on_move = false, -- Dismiss the floating window when moving the cursor.
  force_close = true, -- passed into vim.api.nvim_win_close's second argument. See :h nvim_win_close
  bufhidden = "wipe", -- the bufhidden option to set on the floating window. See :h bufhidden
  stack_floating_preview_windows = true, -- Whether to nest floating windows
  preview_window_title = { enable = true, position = "left" }, -- Whether to set the preview window title as the filename
  zindex = 1, -- Starting zindex for the stack of floating windows
}

require'nvim-web-devicons'.setup {
 -- your personnal icons can go here (to override)
 -- you can specify color or cterm_color instead of specifying both of them
 -- DevIcon will be appended to `name`
 override = {
  zsh = {
    icon = "",
    color = "#428850",
    cterm_color = "65",
    name = "Zsh"
  }
 };
 -- globally enable different highlight colors per icon (default to true)
 -- if set to false all icons will have the default icon's color
 color_icons = true;
 -- globally enable default icons (default to false)
 -- will get overriden by `get_icons` option
 default = true;
 -- globally enable "strict" selection of icons - icon will be looked up in
 -- different tables, first by filename, and if not found by extension; this
 -- prevents cases when file doesn't have any extension but still gets some icon
 -- because its name happened to match some extension (default to false)
 strict = true;
 -- set the light or dark variant manually, instead of relying on `background`
 -- (default to nil)
 variant = "light|dark";
 -- same as `override` but specifically for overrides by filename
 -- takes effect when `strict` is true
 override_by_filename = {
  [".gitignore"] = {
    icon = "",
    color = "#f1502f",
    name = "Gitignore"
  }
 };
 -- same as `override` but specifically for overrides by extension
 -- takes effect when `strict` is true
 override_by_extension = {
  ["log"] = {
    icon = "",
    color = "#81e043",
    name = "Log"
  }
 };
 -- same as `override` but specifically for operating system
 -- takes effect when `strict` is true
 override_by_operating_system = {
  ["apple"] = {
    icon = "",
    color = "#A2AAAD",
    cterm_color = "248",
    name = "Apple",
  },
 };
}
