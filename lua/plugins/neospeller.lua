return {
  dir = "~/plugins/neospeller.nvim",
  lazy = false,
  opts = {},
  cmd = "CheckSpell",
  keys = {
    { "<leader>S", ":CheckSpell<CR>", mode = { "x", "n" },  desc = "Check spelling" },
    { "<leader>D", ":CheckSpellText<CR>", mode = { "x", "n" },  desc = "Check spelling" }
  }
}
