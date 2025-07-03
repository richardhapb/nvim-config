local utils = require 'functions.utils'

return {
  dir = '~/plugins/pytest.nvim',
  config = function()
    require 'pytest'.setup {
      docker = {
        enabled = function()
          return vim.fn.getcwd():find("ddirt") ~= nil or vim.fn.getcwd():find("fundfridge") ~= nil
        end,
        container = function()
          if vim.fn.getcwd():find("fundfridge") ~= nil then
            return "fundfridge-web-1"
          end

          if vim.fn.getcwd():find("ddirt") == nil then return end

          local parent_dir = utils.get_root_cwd_dir()
          return parent_dir .. "-web-1"
        end,
        enable_docker_compose = true,
        docker_compose_service = 'web',
        local_path_prefix = function()
          if vim.fn.getcwd():find("ddirt") then
            return "app"
          elseif vim.fn.getcwd():find("fundfridge") then
            return "fundfridge"
          end

          return ""
        end
      },
      django = {
        enabled = true
      },
    }
  end
}
