return {
  'pwntester/octo.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim',
    'nvim-tree/nvim-web-devicons',
    "williamboman/mason.nvim"
  },
  config = function()
    if vim.fn.executable('gh') == 0 then
      vim.cmd('MasonInstall gh')
    end

    vim.treesitter.language.register('markdown', 'octo')

    require 'octo'.setup {
      ssh_aliases = { ["github.com-syzlab"] = "github.com" },
      github_hostname = "github.com",
      users = "assignable"
    }
  end
}
