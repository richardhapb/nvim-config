local path = vim.fs.joinpath(vim.fn.expand("$HOME"), "proj", "lsproxy", "target", "debug", "lsproxy")

return {
  cmd = { path, '--stdio' },
  cmd_env = { RUST_LOG = "none,lsproxy=trace" },
  filetypes = { "python" },
  root_dir = "/Users/richard/dev/ddirt/development/app"
}
