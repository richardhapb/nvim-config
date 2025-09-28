local utils = require 'functions.utils'
local M = {}

-- Core configuration
M.config = {
  window = {
    width_ratio = 0.9,
    height_ratio = 0.9,
    border = "rounded",
    winblend = 10,
  },
  preview = {
    width_ratio = 0.6,
    line_context = 100, -- Lines before and after match to show
    max_lines = 500,
  },
  tools = {
    finder = vim.fn.executable("fd") == 1 and "fd" or (vim.fn.executable("git") == 1 and "git" or "find"),
    searcher = vim.fn.executable("rg") == 1 and "rg" or "grep",
    viewer = vim.fn.executable("bat") == 1 and "bat" or (vim.fn.executable("batcat") == 1 and "batcat" or "cat"),
  }
}

-- Utility functions
local function get_tmp_file(prefix)
  return (vim.env.TMPDIR or "/tmp") .. "/" .. prefix .. "_" .. vim.fn.getpid()
end

local function escape_shell(str)
  return "'" .. str:gsub("'", "'\"'\"'") .. "'"
end

local function trim(str)
  return str:gsub("^%s+", ""):gsub("%s+$", "")
end

-- Table handling utilities
local function table_to_fzf_items(tbl, formatter)
  local items = {}
  if formatter then
    for i, item in ipairs(tbl) do
      table.insert(items, formatter(item, i))
    end
  else
    for i, item in ipairs(tbl) do
      if type(item) == "table" then
        -- Handle various table formats
        if item.filename or item.file then
          local file = item.filename or item.file
          local line = item.lnum or item.line or ""
          local col = item.col or ""
          local text = item.text or ""
          table.insert(items, string.format("%s:%s:%s:%s", file, line, col, text))
        elseif item.name or item.label then
          table.insert(items, item.name or item.label)
        else
          table.insert(items, vim.inspect(item))
        end
      else
        table.insert(items, tostring(item))
      end
    end
  end
  return items
end

-- Core FZF interface
---@param opts table Configuration options
function M.fzf_run(opts)
  opts = vim.tbl_deep_extend("force", {
    source = nil,  -- string command or table of items
    sink = nil,    -- function to handle selection
    preview = nil, -- preview command or function
    prompt = "❯ ",
    title = "FZF",
    keymaps = {},
    fzf_opts = "--ansi",
    formatter = nil, -- function to format table items
  }, opts or {})

  local tmp_input = get_tmp_file("fzf_input")
  local tmp_output = get_tmp_file("fzf_output")

  -- Prepare input
  if type(opts.source) == "table" then
    local items = table_to_fzf_items(opts.source, opts.formatter)
    local f = io.open(tmp_input, "w")
    if not f then
      vim.notify("Failed to create input file", vim.log.levels.ERROR)
      return
    end
    for _, item in ipairs(items) do
      f:write(item .. "\n")
    end
    f:close()
    opts.source = "cat " .. escape_shell(tmp_input)
  end

  -- Build FZF command with proper preview
  local cmd_parts = { "fzf" }

  -- Add basic options
  if opts.fzf_opts then
    table.insert(cmd_parts, opts.fzf_opts)
  end

  -- Add prompt
  if opts.prompt then
    table.insert(cmd_parts, "--prompt=" .. escape_shell(opts.prompt))
  end

  -- Add preview if provided
  if opts.preview then
    local preview_cmd = type(opts.preview) == "function" and opts.preview() or opts.preview
    table.insert(cmd_parts, "--preview=" .. escape_shell(preview_cmd))
    table.insert(cmd_parts, "--preview-window=right:60%:wrap")
  end

  table.insert(cmd_parts, "--print-query")
  if opts.fzf_opts:find(".*--multi.*") then
    table.insert(cmd_parts,
      "--bind=ctrl-y:select-all+accept"
    )
  end

  local fzf_command = table.concat(cmd_parts, " ")

  -- Complete shell command
  local full_cmd = string.format(
    "%s | %s > %s 2>/dev/null || true",
    opts.source,
    fzf_command,
    escape_shell(tmp_output)
  )

  -- Create floating window
  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * M.config.window.width_ratio)
  local height = math.floor(vim.o.lines * M.config.window.height_ratio)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    border = M.config.window.border,
    style = "minimal",
    title = " " .. opts.title .. " ",
    title_pos = "center",
  })

  vim.bo[buf].bufhidden = "wipe"
  vim.wo[win].winblend = M.config.window.winblend

  local function on_exit(_, code, _)
    pcall(vim.api.nvim_win_close, win, true)

    -- Always cleanup input file
    pcall(os.remove, tmp_input)

    -- Check if user cancelled (ESC) vs actual error
    if code == 129 then -- FZF cancelled with ESC
      pcall(os.remove, tmp_output)
      return
    end

    -- Don't error on code 1 (no selection), that's normal
    if code ~= 0 and code ~= 1 then
      vim.notify("FZF failed with code: " .. code, vim.log.levels.ERROR)
      pcall(os.remove, tmp_output)
      return
    end

    -- Read selection
    if vim.fn.filereadable(tmp_output) == 0 then
      pcall(os.remove, tmp_output)
      return -- No selection made
    end

    -- Read output: first line = query (because of --print-query), rest = selections
    local f = io.open(tmp_output, "r")
    if not f then
      pcall(os.remove, tmp_output)
      return
    end
    local data = f:read("*a") or ""
    f:close()
    pcall(os.remove, tmp_output)

    if data == "" then return end

    local lines = {}
    for line in data:gmatch("[^\n]+") do
      line = trim(line)
      if line ~= "" then table.insert(lines, line) end
    end
    if #lines == 0 then return end

    local query = lines[1]
    local selections = {}
    for i = 2, #lines do
      table.insert(selections, lines[i])
    end

    if #selections > 0 and opts.sink then
      local success, err = pcall(opts.sink, selections, { prompt = query, title = opts.title, buf = buf })
      if not success then
        vim.notify("Error opening selection: " .. tostring(err), vim.log.levels.ERROR)
        return
      end
    end
  end


  local chan = vim.fn.jobstart({ "bash", "-c", full_cmd }, {
    term = true,
    on_exit = on_exit,
  })

  -- Key mappings
  local kopts = { silent = true, buffer = buf }
  vim.keymap.set("t", "<ESC>", "<C-\\><C-n>:q<CR>", kopts)
  vim.keymap.set("n", "<ESC>", ":q<CR>", kopts)
  vim.keymap.set("n", "q", ":q<CR>", kopts)

  for _, keymap in ipairs(opts.keymaps) do
    local map_desc = keymap[4] or ""
    vim.keymap.set(keymap[1], keymap[2], function()
        opts.sink = keymap[3]
        vim.api.nvim_chan_send(chan, "\x19")
      end,
      vim.tbl_extend("force", kopts, { desc = map_desc }))
  end

  vim.cmd("startinsert")
end

-- Resource-specific implementations

-- Files
function M.files(opts)
  opts = opts or {}

  local function get_file_cmd()
    if M.config.tools.finder == "fd" then
      return "fd --type f --strip-cwd-prefix --hidden --follow --exclude .git"
    elseif M.config.tools.finder == "git" then
      return "git ls-files --cached --others --exclude-standard 2>/dev/null || find . -type f 2>/dev/null"
    else
      return "find . -type f -not -path './.git/*' 2>/dev/null"
    end
  end

  local function get_preview_cmd()
    if M.config.tools.viewer == "bat" then
      return "bat --style=numbers --color=always --line-range=:500 {}"
    elseif M.config.tools.viewer == "batcat" then
      return "batcat --style=numbers --color=always --line-range=:500 {}"
    else
      return "head -500 {}"
    end
  end

  M.fzf_run(vim.tbl_extend("force", {
    source = get_file_cmd(),
    preview = get_preview_cmd(),
    title = "Files",
    fzf_opts = "--ansi --multi",
    sink = function(selections)
      for i, file in ipairs(selections) do
        local path = vim.fn.fnameescape(file)
        if i == 1 then
          vim.cmd("edit " .. path)
        else
          vim.cmd("tabedit " .. path)
        end
      end
    end,
  }, opts))
end

-- Buffers
function M.buffers(opts)
  opts = opts or {}

  local buffers = {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].buflisted and vim.api.nvim_buf_is_loaded(b) then
      local name = vim.api.nvim_buf_get_name(b)
      if name == "" then
        name = "[No Name]"
      else
        name = vim.fn.fnamemodify(name, ":.")
      end
      local modified = vim.bo[b].modified and " [+]" or ""
      table.insert(buffers, {
        id = b,
        display = string.format("%d: %s%s", b, name, modified),
        name = name,
      })
    end
  end

  M.fzf_run(vim.tbl_extend("force", {
    source = buffers,
    formatter = function(buf) return buf.display end,
    title = "Buffers",
    fzf_opts = "--ansi --delimiter=: --with-nth=2..",
    preview = function()
      local bat_cmd = M.config.tools.viewer == "batcat" and "batcat" or "bat"
      if M.config.tools.viewer == "bat" or M.config.tools.viewer == "batcat" then
        return 'buf_id=$(echo {} | cut -d: -f1); ' ..
            'file=$(nvim --headless -c "echo nvim_buf_get_name($buf_id)" -c "qa!" 2>/dev/null); ' ..
            'if [ -f "$file" ]; then ' ..
            bat_cmd .. ' --style=numbers --color=always --line-range=:500 "$file"; ' ..
            'else echo "Buffer preview not available"; fi'
      else
        return 'echo "Buffer preview not available"'
      end
    end,
    sink = function(selections)
      for _, selection in ipairs(selections) do
        local buf_id = selection:match("^(%d+):")
        if buf_id and vim.api.nvim_buf_is_valid(tonumber(buf_id)) then
          vim.cmd("buffer " .. buf_id)
          break
        end
      end
    end,
  }, opts))
end

-- Grep
function M.grep(search_term, opts)
  opts = opts or {}
  search_term = search_term or vim.fn.input("Search for: ")
  if search_term == "" then return end

  local function get_grep_cmd()
    if M.config.tools.searcher == "rg" then
      return string.format("rg --vimgrep --smart-case --no-heading --hidden --glob '!.git' --glob '!node_modules' %s",
        escape_shell(search_term))
    else
      return string.format("grep -rn --exclude-dir=.git --exclude-dir=node_modules %s .", escape_shell(search_term))
    end
  end

  local function get_grep_preview()
    local context = M.config.preview.line_context
    if M.config.tools.viewer == "bat" or M.config.tools.viewer == "batcat" then
      local bat_cmd = M.config.tools.viewer
      return 'file=$(echo {} | cut -d: -f1); line=$(echo {} | cut -d: -f2); ' ..
          'if [ -f "$file" ] && [ -n "$line" ] && [ "$line" -gt 0 ] 2>/dev/null; then ' ..
          'start=$((line-' .. context .. ')); [ "$start" -lt 1 ] && start=1; ' ..
          'end=$((line+' .. context .. ')); [ "$start" -gt $((end-' .. context .. ')) ]; start=1; ' ..
          bat_cmd .. ' --style=numbers --color=always --highlight-line="$line" --line-range="$start:$end" "$file"; ' ..
          'else ' .. bat_cmd .. ' --style=numbers --color=always "$file"; fi'
    end

    return 'file=$(echo {} | cut -d: -f1); line=$(echo {} | cut -d: -f2); ' ..
        'if [ -f "$file" ] && [ -n "$line" ] && [ "$line" -gt 0 ] 2>/dev/null; then ' ..
        'start=$((line-50)); [ "$start" -lt 1 ] && start=1; ' ..
        'end=$((line+50)); ' ..
        'sed -n "${start},${end}p" "$file" | nl -ba -v"$start"; ' ..
        'else cat -n "$file"; fi'
  end

  M.fzf_run(vim.tbl_extend("force", {
    source = get_grep_cmd(),
    preview = get_grep_preview(),
    title = "Grep: " .. search_term,
    fzf_opts = "--ansi --delimiter=: --preview-window=right:60%:wrap:+{2}-/2",
    sink = function(selections)
      for i, selection in ipairs(selections) do
        local parts = vim.split(selection, ":", { plain = true })
        if #parts >= 2 then
          local file = parts[1]
          local line_num = tonumber(parts[2])
          local path = vim.fn.fnameescape(file)
          if i == 1 then
            vim.cmd("edit " .. path)
          else
            vim.cmd("tabedit " .. path)
          end
          if line_num then
            vim.api.nvim_win_set_cursor(0, { line_num, 0 })
            vim.cmd("normal! zz")
          end
        end
      end
    end,
  }, opts))
end

-- Live grep
function M.live_grep(opts)
  opts = opts or {}

  local function get_rg_cmd()
    if M.config.tools.searcher == "rg" then
      return "rg --vimgrep --smart-case --no-heading --hidden --glob '!.git' --glob '!node_modules'"
    else
      return "grep -rn --exclude-dir=.git --exclude-dir=node_modules"
    end
  end

  local function get_preview_cmd()
    local context = M.config.preview.line_context
    if M.config.tools.viewer == "bat" or M.config.tools.viewer == "batcat" then
      local bat_cmd = M.config.tools.viewer
      -- Show specified lines before and after the match
      return 'file=$(echo {} | cut -d: -f1); line=$(echo {} | cut -d: -f2); ' ..
          'if [ -f "$file" ] && [ -n "$line" ] && [ "$line" -gt 0 ] 2>/dev/null; then ' ..
          'start=$((line-' .. context .. ')); [ "$start" -lt 1 ] && start=1; ' ..
          'end=$((line+' .. context .. ')); [ "$start" -gt $((end-' .. context .. ')) ]; start=1; ' ..
          bat_cmd .. ' --style=numbers --color=always --highlight-line="$line" --line-range="$start:$end" "$file"; ' ..
          'else echo "Cannot preview"; fi'
    end
    -- Fallback for when bat is not available
    return 'file=$(echo {} | cut -d: -f1); line=$(echo {} | cut -d: -f2); ' ..
        'if [ -f "$file" ] && [ -n "$line" ] && [ "$line" -gt 0 ] 2>/dev/null; then ' ..
        'start=$((line-50)); [ "$start" -lt 1 ] && start=1; end=$((line+50)); ' ..
        'sed -n "${start},${end}p" "$file" | nl -ba -v"$start"; ' ..
        'else cat "$file" 2>/dev/null || echo "Cannot preview"; fi'
  end

  local tmp_output = get_tmp_file("fzf_output")
  local rg_base = get_rg_cmd()

  local cmd_parts = { "fzf" }
  table.insert(cmd_parts, "--ansi")
  table.insert(cmd_parts, "--disabled")
  table.insert(cmd_parts, "--delimiter=:")
  -- Preview window: show on right, 60% width, center on the matched line
  table.insert(cmd_parts, "--preview-window=right:60%:wrap:+{2}-/2")
  table.insert(cmd_parts, "--prompt='Live Grep> '")
  table.insert(cmd_parts, "--preview=" .. escape_shell(get_preview_cmd()))
  table.insert(cmd_parts, "--bind=" .. escape_shell("change:reload(" .. rg_base .. " {q} || true)"))

  local fzf_command = table.concat(cmd_parts, " ")

  -- Start with empty input but allow typing to trigger search
  local full_cmd = string.format(
    "echo '' | %s > %s 2>/dev/null || true",
    fzf_command,
    escape_shell(tmp_output)
  )

  -- Create floating window
  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * M.config.window.width_ratio)
  local height = math.floor(vim.o.lines * M.config.window.height_ratio)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    border = M.config.window.border,
    style = "minimal",
    title = " Live Grep ",
    title_pos = "center",
  })

  vim.bo[buf].bufhidden = "wipe"
  vim.wo[win].winblend = M.config.window.winblend

  vim.fn.jobstart({ "bash", "-c", full_cmd }, {
    term = true,
    on_exit = function(_, code, _)
      pcall(vim.api.nvim_win_close, win, true)

      if code == 129 then -- ESC
        pcall(os.remove, tmp_output)
        return
      end

      if code ~= 0 and code ~= 1 then
        vim.notify("Live grep failed with code: " .. code, vim.log.levels.ERROR)
        pcall(os.remove, tmp_output)
        return
      end

      if vim.fn.filereadable(tmp_output) == 0 then
        pcall(os.remove, tmp_output)
        return
      end

      local f = io.open(tmp_output, "r")
      if not f then
        pcall(os.remove, tmp_output)
        return
      end
      local data = f:read("*a") or ""
      f:close()
      pcall(os.remove, tmp_output)

      local selections = {}
      for line in data:gmatch("[^\n]+") do
        line = trim(line)
        if line ~= "" then
          table.insert(selections, line)
        end
      end

      if #selections > 0 then
        vim.schedule(function()
          for i, selection in ipairs(selections) do
            local parts = vim.split(selection, ":", { plain = true })
            if #parts >= 2 then
              local file = parts[1]
              local line_num = tonumber(parts[2])
              local path = vim.fn.fnameescape(file)
              if i == 1 then
                vim.cmd("edit " .. path)
              else
                vim.cmd("tabedit " .. path)
              end
              if line_num then
                vim.api.nvim_win_set_cursor(0, { line_num, 0 })
                vim.cmd("normal! zz")
              end
            end
          end
        end)
      end
    end,
  })

  local kopts = { silent = true, buffer = buf }
  vim.keymap.set("t", "<ESC>", "<C-\\><C-n>:q<CR>", kopts)
  vim.keymap.set("n", "<ESC>", ":q<CR>", kopts)
  vim.keymap.set("n", "q", ":q<CR>", kopts)

  vim.cmd("startinsert")
end

-- Help tags
function M.help_tags(opts)
  opts = opts or {}

  M.fzf_run(vim.tbl_extend("force", {
    source = "cut -f1 " .. vim.fn.expand("$VIMRUNTIME/doc/tags") .. " | sort -u",
    title = "Help Tags",
    sink = function(selections)
      for _, tag in ipairs(selections) do
        vim.cmd("help " .. tag)
        break
      end
    end,
  }, opts))
end

-- Keymaps
function M.keymaps(opts)
  opts = opts or {}

  local keymaps = {}
  for _, mode in ipairs({ 'n', 'i', 'v', 'x', 't', 'c', 'o' }) do
    local maps = vim.api.nvim_get_keymap(mode)
    for _, map in ipairs(maps) do
      local desc = map.desc or map.rhs or ""
      table.insert(keymaps, {
        mode = mode,
        lhs = map.lhs,
        rhs = map.rhs,
        desc = desc,
        display = string.format("[%s] %-20s → %s", mode, map.lhs, desc)
      })
    end
  end

  M.fzf_run(vim.tbl_extend("force", {
    source = keymaps,
    formatter = function(km) return km.display end,
    title = "Keymaps",
    fzf_opts = "--ansi --delimiter=→",
    sink = function(selections)
      -- Just show the keymap, don't execute
      for _, selection in ipairs(selections) do
        local mode = selection:match("%[(.-)%]")
        local lhs = selection:match("%] (.-) →")
        if mode and lhs then
          print(string.format("Mode: %s, Key: %s", mode, lhs))
        end
        break
      end
    end,
  }, opts))
end

-- Commands
function M.commands(opts)
  opts = opts or {}

  local commands = vim.api.nvim_get_commands({})
  local cmd_list = {}
  for name, def in pairs(commands) do
    table.insert(cmd_list, {
      name = name,
      definition = def.definition or "",
      display = string.format("%-30s %s", name, def.definition or "")
    })
  end

  M.fzf_run(vim.tbl_extend("force", {
    source = cmd_list,
    formatter = function(cmd) return cmd.display end,
    title = "Commands",
    sink = function(selections)
      for _, selection in ipairs(selections) do
        local cmd = selection:match("^(%S+)")
        if cmd then
          vim.cmd(cmd)
        end
        break
      end
    end,
  }, opts))
end

-- Colorschemes
function M.colorschemes(opts)
  opts = opts or {}

  local colors = vim.fn.getcompletion("", "color")

  M.fzf_run(vim.tbl_extend("force", {
    source = colors,
    title = "Colorschemes",
    sink = function(selections)
      for _, colorscheme in ipairs(selections) do
        vim.cmd("colorscheme " .. colorscheme)
        break
      end
    end,
  }, opts))
end

-- Quickfix/Location list
function M.quickfix(opts)
  opts = opts or {}

  local qflist = vim.fn.getqflist()
  if #qflist == 0 then
    vim.notify("Quickfix list is empty", vim.log.levels.INFO)
    return
  end

  local items = {}
  for i, item in ipairs(qflist) do
    local bufname = vim.fn.bufname(item.bufnr)
    local filename = bufname ~= "" and vim.fn.fnamemodify(bufname, ":.") or "[No Name]"
    local text = item.text or ""
    table.insert(items, {
      idx = i,
      filename = filename,
      lnum = item.lnum,
      col = item.col,
      text = text,
      display = string.format("%s:%d:%d: %s", filename, item.lnum, item.col, text)
    })
  end

  M.fzf_run(vim.tbl_extend("force", {
    source = items,
    formatter = function(item) return item.display end,
    title = "Quickfix",
    fzf_opts = "--ansi --delimiter=:",
    preview = function()
      local context = M.config.preview.line_context
      if M.config.tools.viewer == "bat" or M.config.tools.viewer == "batcat" then
        local bat_cmd = M.config.tools.viewer
        return 'file=$(echo {} | cut -d: -f1); line=$(echo {} | cut -d: -f2); ' ..
            'if [ -f "$file" ] && [ -n "$line" ] && [ "$line" -gt 0 ] 2>/dev/null; then ' ..
            'start=$((line-' .. context .. ')); [ "$start" -lt 1 ] && start=1; ' ..
            'end=$((line+' .. context .. ')); ' ..
            bat_cmd .. ' --style=numbers --color=always --highlight-line="$line" --line-range="$start:$end" "$file"; ' ..
            'else ' .. bat_cmd .. ' --style=numbers --color=always "$file"; fi'
      end
      return 'file=$(echo {} | cut -d: -f1); line=$(echo {} | cut -d: -f2); ' ..
          'if [ -f "$file" ] && [ -n "$line" ] && [ "$line" -gt 0 ] 2>/dev/null; then ' ..
          'start=$((line-50)); [ "$start" -lt 1 ] && start=1; end=$((line+50)); ' ..
          'sed -n "${start},${end}p" "$file" | nl -ba -v"$start"; ' ..
          'else cat -n "$file"; fi'
    end,
    sink = function(selections)
      for _, selection in ipairs(selections) do
        local parts = vim.split(selection, ":", { plain = true })
        if #parts >= 2 then
          local file = parts[1]
          local line_num = tonumber(parts[2])
          vim.cmd("edit " .. vim.fn.fnameescape(file))
          if line_num then
            vim.api.nvim_win_set_cursor(0, { line_num, 0 })
            vim.cmd("normal! zz")
          end
        end
        break
      end
    end,
  }, opts))
end

-- Git files
function M.git_files(opts)
  opts = opts or {}

  if vim.fn.isdirectory(".git") == 0 then
    vim.notify("Not in a git repository", vim.log.levels.WARN)
    return
  end

  M.fzf_run(vim.tbl_extend("force", {
    source = "git ls-files --cached --others --exclude-standard",
    preview = function()
      if M.config.tools.viewer == "bat" or M.config.tools.viewer == "batcat" then
        return M.config.tools.viewer .. " --style=numbers --color=always --line-range=:500 {}"
      else
        return "head -500 {}"
      end
    end,
    fzf_opts = "--ansi --multi",
    title = "Git Files",
    sink = function(selections)
      for i, file in ipairs(selections) do
        local path = vim.fn.fnameescape(file)
        if i == 1 then
          vim.cmd("edit " .. path)
        else
          vim.cmd("tabedit " .. path)
        end
      end
    end,
  }, opts))
end

-- Registers
function M.registers(opts)
  opts = opts or {}

  local registers = {}
  for _, reg in ipairs({ '"', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', '+', '*', '/', '=' }) do
    local content = vim.fn.getreg(reg)
    if content ~= "" then
      local preview = content:gsub("\n", "\\n"):sub(1, 100)
      table.insert(registers, {
        reg = reg,
        content = content,
        display = string.format("[%s] %s", reg, preview)
      })
    end
  end

  M.fzf_run(vim.tbl_extend("force", {
    source = registers,
    formatter = function(reg) return reg.display end,
    title = "Registers",
    sink = function(selections)
      for _, selection in ipairs(selections) do
        local reg = selection:match("%[(.-)%]")
        if reg then
          vim.cmd("normal! \"" .. reg .. "p")
        end
        break
      end
    end,
  }, opts))
end

function M.docker_containers(opts)
  opts = opts or {}

  if vim.fn.executable("docker") == 0 then
    vim.notify("Docker is not installed", vim.log.levels.WARN)
    return
  end

  M.fzf_run(vim.tbl_extend("force", {
    source = [[ docker ps -a --format '{{.Names}}\t{{.State}}\t{{.Image}}' \
| awk -F '\t' '{
  name="\033[32m"$1"\033[0m"
  status="\033[33m"$2"\033[0m"
  image="\033[34m"$3"\033[0m"
  printf "%-40s %-30s %-30s\n", name, status, image
}' | sed '1d' ]],
    preview = "container=$(echo {} | awk '{print $1}'); docker logs -n 100 $container",
    title = "Docker containers",
    fzf_opts = "--ansi --multi",
    keymaps = {
      { "t", "<C-r>", function(selections, args)
        for _, container in ipairs(selections) do
          if container:find("^" .. args.prompt .. ".*$") then
            container = container:match("^(%S+)")
            vim.system({ "docker", "start", container }, {}, function()
              vim.schedule(function() vim.notify(container .. " started", vim.log.levels.INFO) end)
            end)
          end
        end
      end, "Run containers with prefix" },
      { "t", "<C-c>", function(selections, args)
        for _, container in ipairs(selections) do
          if container:find("^" .. args.prompt .. ".*$") then
            container = container:match("^(%S+)")
            vim.system({ "docker", "stop", container }, {}, function()
              vim.schedule(function() vim.notify(container .. " stopped", vim.log.levels.INFO) end)
            end)
          end
        end
      end, "Stop containers with prefix" }
    },
    sink = function(selections)
      for _, container in ipairs(selections) do
        container = container:match("^(%S+)")
        vim.fn.system("docker start " .. container)
      end
    end,
  }, opts))
end

-- Setup function with all keymaps
function M.setup(user_config)
  -- Merge user config
  if user_config then
    M.config = vim.tbl_deep_extend("force", M.config, user_config)
  end

  -- Core mappings
  vim.keymap.set("n", "<leader><leader>", M.files, { desc = "Find Files" })
  vim.keymap.set("n", "<leader>bb", M.buffers, { desc = "Find Buffers" })
  vim.keymap.set("n", "<leader>fl", M.grep, { desc = "Grep" })
  vim.keymap.set("n", "<leader>fg", M.live_grep, { desc = "Live Grep" })
  vim.keymap.set("n", "<leader>fd", M.docker_containers, { desc = "Docker containers" })

  -- Additional mappings
  vim.keymap.set("n", "<leader>fh", M.help_tags, { desc = "Help Tags" })
  vim.keymap.set("n", "<leader>fk", M.keymaps, { desc = "Keymaps" })
  vim.keymap.set("n", "<leader>fc", M.commands, { desc = "Commands" })
  vim.keymap.set("n", "<leader>ft", M.colorschemes, { desc = "Colorschemes" })
  vim.keymap.set("n", "<leader>fq", M.quickfix, { desc = "Quickfix" })
  vim.keymap.set("n", "<leader>gf", M.git_files, { desc = "Git Files" })
  vim.keymap.set("n", "<leader>fr", M.registers, { desc = "Registers" })

  -- Convenient shortcuts
  vim.keymap.set("n", "<leader>f/", function()
    M.grep(vim.fn.expand("<cword>"))
  end, { desc = "Grep word under cursor" })

  vim.keymap.set("v", "<leader>fv", function()
    local text = utils.get_visual_selection()
    M.grep(text)
  end, { desc = "Grep visual selection" })

  vim.api.nvim_create_user_command("FZF", function(opts)
    local func_name = opts.args
    if M[func_name] then
      M[func_name]()
    else
      vim.notify("Unknown FZF function: " .. func_name, vim.log.levels.ERROR)
    end
  end, {
    nargs = 1,
    complete = function()
      return vim.tbl_keys(M)
    end,
    desc = 'FZF funtions'
  })
end

return M
