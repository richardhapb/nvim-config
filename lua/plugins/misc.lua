return function(use)
    use {
        'voldikss/vim-floaterm',
        config = function()
            vim.g.floaterm_width = 0.9
            vim.g.floaterm_height = 0.8
            vim.api.nvim_set_keymap('n', '<leader>t', ':FloatermToggle<CR>', { noremap = true, silent = true })
        end,
    }

    use {
        'prettier/vim-prettier',
        run = 'npm install',
        ft = { 'javascript', 'typescript', 'css', 'html', 'json', 'markdown' },
        config = function()
            vim.g['prettier#autoformat'] = 1
        end,
    }

    use {
        'christoomey/vim-tmux-navigator',
        config = function()
            vim.g.tmux_navigator_no_mappings = 1
        end,
    }
end
