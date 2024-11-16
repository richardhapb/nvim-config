require("base")
require("keymaps")
require("plugins")

local has = function(x)
    return vim.fn.has(x) == 1
end

local is_mac = has "macunix"
local is_windows = has "win32"

if is_mac then
    require("macos")
elseif is_windows then
    require("windows")
elseif is_linux then
    require("linux")
end

