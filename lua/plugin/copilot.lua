vim.api.nvim_create_user_command("CopilotCommit", function()
  vim.cmd("G commit")
  local buf = vim.api.nvim_get_current_buf()

  vim.fn.jobstart({ "copilot-chat", "commit" }, {
    cwd = vim.fn.getcwd(),
    stdin = "null",
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(code, stdout)
      if code ~= 0 then
        vim.api.nvim_buf_set_lines(buf, 0, 0, false, stdout)
      end
    end,
    on_stderr = function(_, stderr)
      vim.print(stderr)
    end,
  })
end, {})

vim.keymap.set("n", "<leader>am", ":CopilotCommit<CR>", { silent = true })
