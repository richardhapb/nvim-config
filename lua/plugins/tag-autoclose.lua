return {
  "windwp/nvim-ts-autotag",
  dependencies = {
    'nvim-lua/plenary.nvim'
  },

  config = function()
    require('nvim-ts-autotag').setup({
      opts = {
        -- Defaults
        enable_close = true,
        enable_rename = true,
        enable_close_on_slash = true
      },
    })
  end
}
