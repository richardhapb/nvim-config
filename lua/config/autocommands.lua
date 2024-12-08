vim.api.nvim_create_autocmd("BufWritePre", {
   desc = "Format python on write using black",
   group = vim.api.nvim_create_augroup("black_on_save", { clear = true }),
   callback = function (args)
      if vim.bo[args.buf].filetype == "python" then
         require("lint").try_lint("pylint")
      end
   end
})
