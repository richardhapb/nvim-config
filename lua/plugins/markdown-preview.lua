return {
   "iamcco/markdown-preview.nvim",
   cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
   ft = { "markdown" },
   build = function() vim.fn["mkdp#util#install"]() end,
   init = function()
      vim.g.mkdp_filetypes = { "markdown" }
   end,
   config = function()
      -- If mac use Safari because I have Brave setup to dark mode and preview is incorrect
      if vim.fn.has("mac") == 1 then
         vim.g.mkdp_browser = "safari"
      end
   end,
   keys = {
      { "<leader>M", ":MarkdownPreview<CR>" },
      { "<leader>ms", ":MarkdownPreviewStop<CR>" },
   },
}

