return function(use)
    use 'mfussenegger/nvim-lint'

    -- Configuración de nvim-lint
    require("lint").linters_by_ft = {
        python = { "pylint" },
        javascript = { "eslint" },
    }

    -- Ejecutar linting automáticamente al guardar
    vim.api.nvim_exec([[
        augroup LintAutogroup
            autocmd!
            autocmd BufWritePost *.py lua require('lint').try_lint()
            autocmd BufWritePost *.js lua require('lint').try_lint()
        augroup END
    ]], true)
end
