-- Activar números relativos
vim.opt.number = true
vim.opt.relativenumber = true

-- Usar espacios en lugar de tabs y setear el tamaño de la indentación
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4

-- Resaltado de sintaxis
vim.cmd('syntax on')
vim.opt.termguicolors = true

-- Asegura la transparencia en Neovim
vim.cmd("highlight Normal guibg=NONE ctermbg=NONE")
vim.cmd("highlight NonText guibg=NONE ctermbg=NONE")
vim.cmd("highlight LineNr guibg=NONE")        -- Línea de número transparente
vim.cmd("highlight SignColumn guibg=NONE")    -- Columna de signos transparente
vim.cmd("highlight EndOfBuffer guibg=NONE")   -- Fondo al final del buffer
vim.opt.termguicolors = true

vim.opt.wrap = false

