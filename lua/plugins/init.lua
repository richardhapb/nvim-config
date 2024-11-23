return require('packer').startup(function(use)
    use 'wbthomason/packer.nvim'

    -- Cargar módulos de plugins
    require("plugins.ui")(use)
    require("plugins.edit")(use)
    require("plugins.lsp")(use)
    require("plugins.tools")(use)
    require("plugins.markdown")(use)
    require("plugins.debug")(use)
    require("plugins.misc")(use)
    require("plugins.lint")(use)
end)

