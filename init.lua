require("config.opts")
require("config.mini_plugins")
require("config.lsp")
require("config.autocommands")
require("config.usercommands")
require("config.keymaps")


if vim.fn.has("mac") then
  require("config.macos")
end

if vim.fn.has("linux") then
  require("config.linux")
end

-- Load environment variables
require("config.colorscheme").enable_custom("rose-pine")
pcall(dofile, vim.fs.joinpath(vim.fn.stdpath("config"), ".env.lua"))
