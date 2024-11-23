return function(use)
    -- Popup.nvim: Soporte para ventanas emergentes (usado por otros plugins)
    use 'nvim-lua/popup.nvim'

    -- Comentarios rápidos
    use {
        'tpope/vim-commentary',
        config = function()
            -- No se necesita configuración específica
        end,
    }

    -- Slime para enviar código a REPLs
    use {
        'jpalardy/vim-slime',
        config = function()
            vim.g.slime_target = "tmux"
            vim.g.slime_default_config = { socket_name = "default", target_pane = "{last}" }
        end,
    }

    -- Mostrar combinaciones de teclas
    use {
        "folke/which-key.nvim",
        config = function()
            require("which-key").setup({})
        end,
    }

    -- Formateo de código
    use {
        'mhartington/formatter.nvim',
        config = function()
            require("formatter").setup({
                filetype = {
                    python = {
                        function()
                            return {
                                exe = "black",
                                args = { "--fast", "-" },
                                stdin = true,
                            }
                        end,
                    },
                    lua = {
                        function()
                            return {
                                exe = "stylua",
                                args = { "--search-parent-directories", "-" },
                                stdin = true,
                            }
                        end,
                    },
                },
            })
            vim.api.nvim_exec([[
                augroup FormatAutogroup
                autocmd!
                autocmd BufWritePost *.py,*.lua FormatWrite
                augroup END
            ]], true)
        end,
    }

    -- Emparejamiento automático de caracteres
    use {
        'windwp/nvim-autopairs',
        config = function()
            require("nvim-autopairs").setup({
                check_ts = true, -- Integración con Treesitter
            })
        end,
    }

    -- Manejo avanzado de delimitadores (paréntesis, comillas, etc.)
    use {
        'kylechui/nvim-surround',
        config = function()
            require("nvim-surround").setup({})
        end,
    }
end
