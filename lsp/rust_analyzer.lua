return {
  cmd = { 'rust-analyzer' },
  filetypes = { 'rust' },
  single_file_support = true,
  root_markers = {
    "Cargo.toml",
    ".git"
  },
  capabilities = {
    experimental = {
      serverStatusNotification = true,
    },
  },
  before_init = function(init_params, config)
    if config.settings and config.settings['rust-analyzer'] then
      init_params.initializationOptions = config.settings['rust-analyzer']
    end
  end,
}
