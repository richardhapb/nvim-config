return {
   "iamcco/markdown-preview.nvim",
   cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
   ft = { "markdown" },
   build = "cd app && npm install",
   init = function()
      vim.g.mkdp_filetypes = { "markdown" }
   end,
   config = function()
      vim.g.mkdp_filetypes = { "markdown" }
   end,
   keys = {
      { "<leader>M", ":MarkdownPreview<CR>" },
      { "<leader>ms", ":MarkdownPreviewStop<CR>" },
   },
}
