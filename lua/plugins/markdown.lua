return function(use)
    use {
        "iamcco/markdown-preview.nvim",
        run = function() vim.fn["mkdp#util#install"]() end,
        ft = { "markdown" },
        setup = function()
            vim.g.mkdp_filetypes = { "markdown" }
        end,
    }

    use {
        "quarto-dev/quarto-nvim",
        requires = { "jmbuhr/otter.nvim", "nvim-treesitter/nvim-treesitter" },
        config = function()
            require("quarto").setup({
                lspFeatures = {
                    languages = { "r", "python", "lua" },
                    diagnostics = { enabled = true, triggers = { "BufWritePost" } },
                    completion = { enabled = true },
                },
                codeRunner = { enabled = true, default_method = "molten" },
            })
        end,
    }

    use {
        "TobinPalmer/pastify.nvim",
        config = function()
            require('pastify').setup({
                opts = { save = 'local', local_path = '/assets/imgs/', default_ft = 'markdown' },
                ft = { markdown = '![]($IMG$)' },
            })
        end,
    }

    use {
        "GCBallesteros/jupytext.nvim",
        config = function()
            require("jupytext").setup({ fmt = "ipynb", sync_on_save = true })
        end,
    }

    use {
        "benlubas/molten-nvim",
        run = ":UpdateRemotePlugins",
        config = function()
            vim.g.molten_output_win_max_height = 12
            vim.g.molten_wrap_output = true
            vim.g.molten_auto_open_output = false
            vim.g.molten_image_provider = "wezterm"
        end,
    }
end
