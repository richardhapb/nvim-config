return function(use)
    use 'windwp/nvim-autopairs'
    require("nvim-autopairs").setup({
        check_ts = true,
    })
end
