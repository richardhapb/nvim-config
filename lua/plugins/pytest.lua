return {
  dir = '~/plugins/pytest.nvim',
  config = function()
    require 'pytest'.setup {
      docker = {
        container = 'ddirt-web-1',
        docker_compose_service = 'web',
      }
    }
  end
}
