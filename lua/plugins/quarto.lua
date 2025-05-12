return {
  {
    "quarto-dev/quarto-nvim",
    dependencies = {
      "jmbuhr/otter.nvim",
      "nvim-treesitter/nvim-treesitter",
      "Vigemus/iron.nvim",
    },
    opts = {
      codeRunner = {
        enabled = true,
        default_method = "iron"
      }
    }
  },
}
