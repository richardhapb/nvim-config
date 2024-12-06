return {
   {
      "scottmckendry/cyberdream.nvim",
      name = "cyberdream",
      lazy = false,
      priority = 1000,
      config = function()
         require("cyberdream").setup({
            transparent = true,
            borderless_telescope = true,
            italic_comments = true,
            extensions = {
               telescope = false
            }
         })
         vim.cmd([[ colorscheme cyberdream ]])
      end
   },
}
