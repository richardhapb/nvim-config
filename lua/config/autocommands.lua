vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("YankConfig", { clear = true }),
  pattern = "*",
  callback = function()
    vim.hl.hl_op({ higroup = "IncSearch", timeout = 200 })
  end,
})

vim.api.nvim_create_autocmd("TermOpen", {
  group = vim.api.nvim_create_augroup("TermConfig", { clear = true }),
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.bo.filetype = "terminal"
  end
})

-- Grouped so re-sourcing init.lua (<leader>I) replaces these rather than
-- stacking another copy on every source.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("TreesitterStart", { clear = true }),
  callback = function()
    pcall(vim.treesitter.start)
  end
})

-- Floating markdown scratch buffers (LSP hover, my own float helpers) get
-- `wrap` from the markdown ftplugin, but that's window-local and the float is
-- created after FileType fires, so it never reaches the popup window. Set wrap
-- directly when such a window opens.
vim.api.nvim_create_autocmd("BufWinEnter", {
  group = vim.api.nvim_create_augroup("FloatMarkdownWrap", { clear = true }),
  callback = function(ev)
    if vim.bo[ev.buf].filetype ~= "markdown" or vim.bo[ev.buf].buftype ~= "nofile" then
      return
    end
    local win = vim.fn.bufwinid(ev.buf)
    if win ~= -1 and vim.api.nvim_win_get_config(win).relative ~= "" then
      vim.wo[win].wrap = true
      vim.wo[win].linebreak = true
    end
  end,
})

--- fff ------
-- Disable mini.completion in the fff.nvim picker prompt
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("FffNoCompletion", { clear = true }),
  pattern = "fff_input",
  callback = function()
    vim.b.minicompletion_disable = true
  end,
})

vim.api.nvim_create_autocmd('PackChanged', {
  callback = function(ev)
    local name, kind = ev.data.spec.name, ev.data.kind
    if name == 'fff.nvim' and (kind == 'install' or kind == 'update') then
      if not ev.data.active then vim.cmd.packadd('fff.nvim') end
      require('fff.download').download_or_build_binary()
    end
  end,
})

-- Prograss bar in Ghostty and nvim msg when LSP load
vim.api.nvim_create_autocmd("LspProgress", {
  group = vim.api.nvim_create_augroup("LspProgressBar", { clear = true }),
  callback = function(ev)
    local value = ev.data.params.value or {}
    local msg = value.message
    if msg == vim.NIL or not msg then
      msg = "done"
    end

    -- rust analyszer in particular has really long LSP messages so truncate them
    if #msg > 40 then
      msg = msg:sub(1, 37) .. "..."
    end

    local percent = value.percentage or 0

    -- :h LspProgress
    vim.api.nvim_echo({ { msg } }, false, {
      id = "lsp",
      source = "lsp-loading",
      kind = "progress",
      title = value.title,
      status = value.kind ~= "end" and "running" or "success",
      percent = percent,
    })

    if not value.kind then return end

    local status = value.kind == "end" and 0 or 1
    local osc_seq = string.format("\27]9;4;%d;%d\a", status, percent)
    if os.getenv("TMUX") then
      osc_seq = string.format("\27Ptmux;\27%s\27\\", osc_seq)
    end

    io.stdout:write(osc_seq)
    io.stdout:flush()
  end,
})
