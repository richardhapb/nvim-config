local M = {}
local running = false
local timer = nil

M.setup = function()
  if timer then
    return vim.notify("Watcher is already running", vim.log.levels.WARN)
  end

  running = true
  timer = vim.uv.new_timer()

  if not timer then
    return vim.notify("Error setting timer")
  end

  -- Start timer with 0ms delay, 11m interval
  timer:start(0, 700000, vim.schedule_wrap(function()
    if running then
      if vim.system({ "pgrep", "jn" }):wait().code ~= 0 then
        vim.notify("jn is not running", vim.log.levels.WARN)
      end
    else
      timer:stop()
      timer:close()
      timer = nil
    end
  end))
end

M.stop = function()
  running = false
  if timer then
    timer:stop()
    timer:close()
    timer = nil
    vim.notify("Watcher stopped", vim.log.levels.INFO)
  end
end

return M
