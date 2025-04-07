local utils = require 'functions.utils'

return {
  dir = '~/plugins/pytest.nvim',
  config = function()
    require 'pytest'.setup {
      docker = {
        enabled = true,
        container = function()
          local parent_dir = utils.get_root_cwd_dir()
          return parent_dir .. "-web-1"
        end,
        enable_docker_compose = true,
        docker_compose_service = 'web',
      },
      django = {
        enabled = true
      },
    }
  end
}
