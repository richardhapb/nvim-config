require("config.opts")
require("config.mini_plugins")

local lsp_enabled = os.getenv("NVIM_LSP_ENABLED")
if not lsp_enabled or lsp_enabled ~= "0" then
  require("config.lsp")
end

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
require("config.colorscheme").enable_custom("gruvbox-dark-hard")
pcall(dofile, vim.fs.joinpath(vim.fn.stdpath("config"), ".env.lua"))

vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("InitConfig", { clear = true }),
  callback = function()
    -- Load a custom configuration to the cwd
    pcall(dofile, vim.fs.joinpath(vim.fn.getcwd(), ".nvim"))
  end
})
