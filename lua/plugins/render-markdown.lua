return {
   'MeanderingProgrammer/render-markdown.nvim',
   dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.icons' },  -- if you use standalone mini plugins
   ft = { 'markdown', 'quarto' },
   ---@module 'render-markdown'
   ---@type render.md.UserConfig
   opts = {},
   cmd = 'RenderMarkdown',
}

