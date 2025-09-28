local utils = require 'functions.utils'

return {
  docker = {
    enabled = function()
      return vim.fn.getcwd():find("ddirt") ~= nil or vim.fn.getcwd():find("fundfridge") ~= nil or
      vim.fn.getcwd():find("agora_hedge") ~= nil
    end,
    container = function()
      if vim.fn.getcwd():find("ddirt") == nil and vim.fn.getcwd():find("agora_hedge") == nil and vim.fn.getcwd():find("fundfridge") == nil then return end

      local parent_dir = utils.get_root_cwd_dir()
      return parent_dir .. "-web-1"
    end,
    enable_docker_compose = true,
    docker_compose_service = 'web',
    local_path_prefix = function()
      if vim.fn.getcwd():find("ddirt") or vim.fn.getcwd():find("agora_hedge") then
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
