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
  settings = {
    ["rust-analyzer"] = {
      cargo = {
        features = "all",
        targetDir = "target/ra",
        allTargets = true
      },
      checkOnSave = {
        enable = true,
      },
      check = {
        command = "clippy",
        allTargets = true
      },
      files = {
        exclude = {
          "**/.git/**",
          "**/target/**",
          "**/node_modules/**",
          "**/dist/**",
          "**/out/**",
        }
      },
      completion = {
        postfix = {
          enable = false,
        },
      },
    },
  },
  before_init = function(init_params, config)
    if config.settings and config.settings['rust-analyzer'] then
      init_params.initializationOptions = config.settings['rust-analyzer']
    end
  end,
}
