return function(use)
    use 'nvim-lua/plenary.nvim'
    use 'nvim-telescope/telescope.nvim'

    use {
        "stevearc/oil.nvim",
        config = function()
            require("oil").setup({
                view_options = { show_hidden = true },
                columns = { "icon", "permissions", "size", "mtime" },
            })
        end,
    }

    use {
        "willothy/wezterm.nvim",
        config = function()
            require("wezterm").setup()
        end,
    }

    use {
        'kyazdani42/nvim-tree.lua',
        config = function()
            require('nvim-tree').setup({
                view = { width = 30, side = 'left' },
                renderer = { highlight_git = true },
                git = { enable = true },
            })
        end,
    }

    use {
        'lewis6991/gitsigns.nvim',
        config = function()
            require('gitsigns').setup({
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
            })
        end,
    }
end
