-- Bootstrap lazy.nvim
local lazyroot = vim.fs.joinpath(vim.fn.stdpath("data"), "lazy")
local lazypath = vim.fs.joinpath(lazyroot, "lazy.nvim")

if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=main", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out,                            "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end

vim.opt.rtp:prepend(lazypath)

-- This is necessary for getting the filetype highlight in telescope for some languages
-- TODO: Create a PR for plenary/telescope to solve it
vim.opt.rtp:append((vim.fs.joinpath(lazyroot, "plenary.nvim")))
require('plenary.filetype')

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    { import = "plugins" },
  },
  -- In lazy.nvim is definded as a boolean, but that is wrong
  ---@diagnostic disable-next-line: assign-type-mismatch
  dev = {
    path = "~/plugins",
    patterns = { 'richardhapb' },
    colorscheme = { "tokyonight" }
  },
  rtp = {
    paths = { vim.fs.joinpath(lazyroot, "plenary.nvim") }
  },
  -- automatically check for plugin updates
  checker = { enabled = true, notify = false },
  change_detection = { notify = false }
})
