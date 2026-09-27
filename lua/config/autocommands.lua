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
  callback = function(args)
    local excluded = { "cmd", "dialog", "msg", "pager", "fff.*" }
    for _, ex in ipairs(excluded) do
      if args.match:match(ex) then
        return
      end
    end

    pcall(vim.treesitter.start, args.buf, args.match)
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

vim.api.nvim_create_autocmd('PackChanged', {
  callback = function(ev)
    local name, kind = ev.data.spec.name, ev.data.kind
    if name == 'fff.nvim' and (kind == 'install' or kind == 'update') then
      if not ev.data.active then vim.cmd.packadd('fff.nvim') end
      require('fff.download').download_or_build_binary()
    end
  end,
})

