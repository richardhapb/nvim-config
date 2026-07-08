local utils = require 'functions.utils'

local keymap = vim.keymap.set
local k = vim.keycode

local function _verify_tmux()
  local tmux_running = false
  if vim.fn.executable 'tmux' == 1 then
    vim.cmd('silent !tmux info')
    tmux_running = vim.v.shell_error == 0
  end

  return tmux_running
end

-- Usercommands
keymap('n', '<leader>do', ':DiffOrig<CR>', { silent = true, desc = 'Compare with original' })

-- Lua dev
keymap('n', '<C-x>', '<cmd>.lua<CR>', { desc = 'Execute lua line' })
keymap('n', '<leader>I', function()
  vim.cmd.source(vim.fs.joinpath(vim.fn.stdpath('config'), 'init.lua'))
  vim.notify('Sourced init.lua', vim.log.levels.INFO)
end, { desc = 'Source init file' })

-- Diagostic
keymap('n', '<leader>dq', vim.diagnostic.setloclist, { noremap = true, desc = 'Send diagnostics to qf' })

-- Edit
keymap('n', '<C-s>', '<cmd>edit .<cr>', { silent = true })
keymap('n', ';;', '<cmd>:w<cr>', { silent = true })
keymap('n', 'x', '"_x', { silent = true })
keymap('x', 'p', '"_xP', { silent = true })
keymap('n', 'db', '"_db', { silent = true })
keymap('n', 'de', '"_de', { silent = true })
keymap('n', 'dw', '"_dw', { silent = true })
keymap('n', '<leader>sa', 'ggVG', { silent = true, desc = 'Select all' })
keymap('n', '<leader>X', function()
  local path = vim.fn.expand('%:.')
  vim.fn.setreg('+', path)
  vim.notify('Copied: ' .. path, vim.log.levels.INFO)
end, { silent = true, desc = 'Copy relative path to clipboard' })
keymap('n', 'D', '"_d$', { silent = true })
keymap('v', 'J', ':m \'>+1<CR>gv=gv', { silent = true })
keymap('v', 'K', ':m \'<-2<CR>gv=gv', { silent = true })
keymap('n', '*', '*N', { noremap = true, silent = true })
keymap('n', 'J', 'mzJ`z')
keymap('n', '<C-d>', '<C-d>zz')
keymap('n', '<C-u>', '<C-u>zz')
keymap('n', 'n', 'nzzzv')
keymap('n', 'N', 'Nzzzv')
keymap('n', '+', '<C-a>', { noremap = true, silent = true, desc = 'Increment number' })
keymap('n', 'mm', '<CMD>make<CR>', { noremap = true, silent = true, desc = 'Make' })
keymap('n', '<leader>Q', vim.diagnostic.setloclist, { noremap = true, silent = true, desc = "Diagnostrics to quick fix" })


-- Remove search highlight if is active
keymap('n', '<Esc>', function()
  if vim.v.hlsearch == 1 then
    vim.cmd.nohl()
    return ''
  else
    return k '<Esc>'
  end
end, { expr = true })


-- UI
keymap('n', 'ss', ':split<CR><C-w>j', { silent = true })
keymap('n', 'sv', ':vsplit<CR><C-w>l', { silent = true })

-- Explorer
keymap('n', '<leader>\\', ':tabnew<CR>', { silent = true, desc = 'New tab' })
keymap('n', '<C-n>', ':tabnext<CR>', { silent = true, desc = 'Next tab' })
keymap('n', '<C-p>', ':tabprevious<CR>', { silent = true, desc = 'Previous tab' })
keymap('n', '<leader>qq', ':tabclose<CR>', { silent = true, desc = 'Close tab' })
keymap('n', '<C-w><left>', '15<C-w><')
keymap('n', '<C-w><right>', '15<C-w>>')
keymap('n', '<C-w><up>', '5<C-w>+')
keymap('n', '<C-w><down>', '5<C-w>-')
keymap('n', '<leader>bd', ':bd!<CR>', { silent = true, desc = 'Close buffer' })
keymap('n', '<leader>.', '<cmd>e tags<cr>', { silent = true, desc = 'Open tags' })

if not _verify_tmux() or utils.is_ssh() then
  keymap('n', '<C-h>', '<C-w>h', { silent = true })
  keymap('n', '<C-j>', '<C-w>j', { silent = true })
  keymap('n', '<C-k>', '<C-w>k', { silent = true })
  keymap('n', '<C-l>', '<C-w>l', { silent = true })
end


-- Open the current selection, can be a file or a link, if it is a oil buffer, open the file selected.
keymap({ 'x', 'n' }, '<leader>o', function()
  local cmd = vim.fn.has "mac" == 1 and "open" or "xdg-open"
  local input = utils.get_visual_selection()
  input = input:gsub('\n', '')

  -- If there is not selection, get the word under the cursor
  if input == '' then
    vim.cmd('normal! "xyiW')
    input = vim.fn.getreg 'x'
  end

  local file_dir
  -- If the filetype is oil, get the current directory and line
  if vim.api.nvim_get_option_value('filetype', { buf = 0 }) == 'oil' then
    local ok, oil = pcall(require, 'oil')
    if ok then
      file_dir = oil.get_current_dir()
      -- Oil lines have the form "line icon file"
      input = vim.fn.getline('.'):gsub('^.*%s.*%s', '')
    end
  else
    file_dir = vim.fn.expand('%:p:h')
  end

  if not file_dir or not input or input == '' then
    return
  end

  local path = vim.fs.joinpath(file_dir, input)
  local args

  if vim.fn.filereadable(path) == 1 then
    args = path
  elseif input:find 'http' or input:find 'www' then
    args = input
  end

  if not args then
    return
  end

  vim.fn.jobstart({ cmd, args }, { detach = true })
end, { desc = 'Open current selection' })

-- Git
keymap('n', '<leader>gg', ':G<CR>', { silent = true, desc = 'Git status' })
keymap('n', '<leader>gc', function()
  ---@type function | nil
  local callback = function(buf)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local msg = vim.fn.join(lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "" then
      vim.notify("Commit message is empty, canceled", vim.log.levels.WARN)
      return
    end

    local tmpfile = vim.fn.tempname()
    vim.fn.writefile(lines, tmpfile)

    vim.system({ "git", "commit", "--file", tmpfile }, { text = true }, function(obj)
      vim.schedule(function()
        if obj.code == 0 then
          vim.notify("Commit successful", vim.log.levels.INFO)
        else
          vim.notify("Commit failed:\n" .. (obj.stderr or ""), vim.log.levels.ERROR)
        end
        vim.fn.delete(tmpfile)
      end)
    end)
  end

  ---@type BufferLogOptions
  local opts = {
    float = true,
    on_exit = function(buf)
      if callback then
        callback(buf)
      end
    end,
    keymaps = { { "n", "<C-c>", function(buf)
      callback = nil
      vim.api.nvim_buf_delete(buf, { force = true })
    end, "Close without commit" } },
    title = "Git commit"
  }
  -- Pick an AI CLI to draft the message: prefer Claude Code, fall back to Codex.
  -- Both read the prompt (instruction + staged diff) from stdin in print mode.
  local gen_cmd
  if vim.fn.executable("codex") == 1 then
    gen_cmd = { "codex", "exec", "-" }
  elseif vim.fn.executable("claude") == 1 then
    gen_cmd = { "claude", "-p" }
  end

  if not gen_cmd then
    vim.notify("Neither 'codex' nor 'claude' found in PATH", vim.log.levels.ERROR)
    return
  end

  local diff = vim.system({ "git", "diff", "--staged" }, { text = true }):wait().stdout or ""
  if vim.trim(diff) == "" then
    vim.notify("No staged changes to commit", vim.log.levels.WARN)
    return
  end

  local prompt = table.concat({
    "You are writing a git commit message for the staged diff below.",
    "",
    "Rules:",
    "- Subject line: conventional-commit style `type(scope): summary`,",
    "  imperative mood, <= 72 chars. Choose a meaningful scope, not a raw",
    "  directory or module path.",
    "- Then a blank line, then a body that explains WHY the change is made and",
    "  what behaviour it affects -- not a restatement of the file list. Wrap at",
    "  ~72 cols. Use bullet points only if there are distinct changes.",
    "- Skip the body if the change is genuinely trivial.",
    "- Do NOT include any trailers, sign-offs, attribution, co-author lines, or",
    "  references to AI/Claude/Codex. Do NOT wrap output in code fences.",
    "- Output ONLY the raw commit message, nothing else.",
    "- Don't explain the commit message, just ouput it",
    "",
    "Staged diff:",
    diff,
  }, "\n")

  -- Drop attribution/trailer lines the model may append regardless of prompt.
  local function strip_trailers(text)
    local lines = vim.split(vim.trim(text), "\n", { plain = true })
    local out = {}
    for _, line in ipairs(lines) do
      local l = line:lower()
      local is_trailer = l:match("^co%-authored%-by:")
        or l:match("^signed%-off%-by:")
        or l:match("generated with") ~= nil
        or line:match("^%s*🤖")
      if not is_trailer then
        table.insert(out, line)
      end
    end
    -- Trim trailing blank lines left behind.
    while #out > 0 and vim.trim(out[#out]) == "" do
      table.remove(out)
    end
    return out
  end

  local buf = utils.buffer_log({}, opts)
  vim.system(gen_cmd, { text = true, stdin = prompt }, function(obj)
    vim.schedule(function()
      if obj.stdout and obj.stdout ~= "" then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, strip_trailers(obj.stdout))
        return
      end

      if obj.stderr and obj.stderr ~= "" then
        vim.notify(obj.stderr, vim.log.levels.WARN)
      end
    end)
  end)
end, { silent = true, desc = 'Git commit' })
keymap('n', '<leader>gC', ':G commit --amend --no-edit<CR>', { silent = true, desc = 'Git commit --amend --no-edit' })
keymap('n', '<leader>gP', ':G push<CR>', { silent = true, desc = 'Git push' })
keymap('n', '<leader>gp', ':G pull --rebase<CR>', { silent = true, desc = 'Git pull --rebase' })
keymap('n', '<leader>gS', ':G stash<CR>', { silent = true, desc = 'Git stash' })
keymap('n', '<leader>gA', ':G add .<CR>', { silent = true, desc = 'Git add .' })
keymap('n', '<leader>gdd', ':G diff<CR>', { silent = true, desc = 'Git diff' })
keymap('n', '<leader>gf', ':G fetch --all<CR>', { silent = true, desc = 'Git fetch' })
keymap('n', '<leader>gF', ':G push --force-with-lease<CR>', { silent = true, desc = 'Git push force with lease' })
keymap('n', '<leader>gb', ':Gitsigns blame<CR>', { silent = true, desc = 'Git blame' })
keymap('n', '<leader>ghh', ':Gitsigns preview_hunk<CR>', { silent = true, desc = 'Git preview hunk' })
keymap('n', '<leader>gdv', ':Gvdiffsplit<CR>', { silent = true, desc = 'Git vertical diff split' })
keymap('n', '<leader>gds', ':Gdiffsplit<CR>', { silent = true, desc = 'Git horizontal diff split' })
keymap({ 'n', 'x' }, '<leader>ghh', ':Gitsigns preview_hunk<CR>', { silent = true, desc = 'Git preview hunk' })
keymap({ 'n', 'x' }, '[g', ':Gitsigns prev_hunk<CR>', { silent = true, desc = 'Git previous hunk' })
keymap({ 'n', 'x' }, ']g', ':Gitsigns next_hunk<CR>', { silent = true, desc = 'Git next hunk' })
keymap({ 'n', 'x' }, '<leader>ghr', ':Gitsigns reset_hunk<CR>', { silent = true, desc = 'Git reset hunk' })

-- New worktree with branch name
keymap('n', '<leader>gw', function()
  local name = vim.fn.input('Worktree name: ')
  utils.create_worktree(name, name)
end, { silent = true, desc = 'Git worktree' })


-- Work's standard branch naming convention
-- feature/richard/yy-mm-dd-feature-name
-- combined with worktree workflow
keymap('n', '<leader>g+', function()
  local feature = vim.fn.input('Feature: ')
  local worktree_name = vim.fn.input('Worktree name: ')
  if feature == '' or worktree_name == '' then
    return
  end

  local branch_name = 'feature/richard/' .. os.date('%y-%m-%d') .. '-' .. feature
  branch_name = string.gsub(branch_name, '%s+', '-')
  vim.notify('Creating branch ' .. branch_name, vim.log.levels.INFO)
  vim.system({ 'git', 'fetch', 'origin' }):wait()

  local dev_worktree_path = vim.fs.joinpath(vim.fn.getcwd(), "development")
  vim.system({ 'git', 'update-ref', 'refs/heads/development', 'refs/remotes/origin/development' }):wait()

  --Update worktree asynchronously
  vim.system({ 'git', '-C', dev_worktree_path, 'checkout', '-f', 'development' }, { detach = true })

  vim.system({ 'git', 'branch', branch_name, 'development' }):wait()

  local upstream = vim.fn.input('Do you want to set upstream? [Y/n]: ')
  if upstream ~= 'n' then
    vim.system({ 'git', 'push', '-u', 'origin', branch_name }):wait()
    vim.notify('Branch ' .. branch_name .. ' set upstream successfully', vim.log.levels.INFO)
  end

  utils.create_worktree(worktree_name, branch_name)

  vim.notify('Branch ' .. branch_name .. ' created successfully', vim.log.levels.INFO)
end, { silent = true, desc = 'Git add a branch and switch' })

-- Set upstream
keymap('n', '<leader>gu', function()
  local branch_name = vim.fn.system('git branch --show-current')
  local upstream = vim.fn.input('Do you want to set upstream to ' .. branch_name .. '? [y/n]: ')
  if upstream == 'y' then
    vim.fn.system('git push -u origin ' .. branch_name)
    vim.notify('Branch ' .. branch_name .. ' set upstream successfully', vim.log.levels.INFO)
  end
end, { silent = true, desc = 'Git set upstream' })

-- Git diff for file name only
keymap('n', '<leader>gda', function()
  utils.git_diff_name_only('HEAD')
  utils.close_all_buffers_but_current()
end, { silent = true, desc = 'Git diff HEAD --name-only' })

keymap('n', 'gh', '<CMD>diffget //2<CR>', { silent = true, desc = 'Git diff get left' })
keymap('n', 'gl', '<CMD>diffget //3<CR>', { silent = true, desc = 'Git diff get right' })

-- Latex
keymap('n', '<leader>lb', ':LatexBuild<CR>', { silent = true, desc = 'Latex build' })
keymap('n', '<leader>lp', ':TeXpresso %<CR>', { silent = true, desc = 'Latex preview' })

-- Spanish
keymap('i', '<A-e>a', 'á', { silent = true })
keymap('i', '<A-e>e', 'é', { silent = true })
keymap('i', '<A-e>i', 'í', { silent = true })
keymap('i', '<A-e>o', 'ó', { silent = true })
keymap('i', '<A-e>u', 'ú', { silent = true })
keymap('i', '<A-n>n', 'ñ', { silent = true })
keymap('i', '<A-e>A', 'Á', { silent = true })
keymap('i', '<A-e>E', 'É', { silent = true })
keymap('i', '<A-e>I', 'Í', { silent = true })
keymap('i', '<A-e>O', 'Ó', { silent = true })
keymap('i', '<A-e>U', 'Ú', { silent = true })
keymap('i', '<A-n>N', 'Ñ', { silent = true })
keymap('i', '<A-?>', '¿', { silent = true })
keymap('i', '<A-1>', '¡', { silent = true })

-- Python
keymap('n', '<leader>rp', ':!python %<CR>', { silent = true, desc = 'Run python' })

-- Rust
keymap('n', '<leader>rr', ':!cargo run<CR>', { silent = true, desc = 'Run cargo' })
keymap('n', '<leader>rc', ':!cargo check<CR>', { silent = true, desc = 'Check cargo' })
keymap('n', '<leader>rt', ':!cargo test<CR>', { silent = true, desc = 'Test cargo' })

-- Terminal
keymap('t', '<esc><esc>', "<C-\\><C-n>", { silent = true, desc = 'Normal mode in terminal' })

-- Throwaway scratch shell (a brand-new terminal each time).
keymap('n', '<leader>cc', "<CMD>term<CR><CMD>startinsert<CR>", { silent = true, desc = 'Open scratch terminal' })

-- Jump to / open the persistent toggle terminal (see lua/plugin/term.lua).
keymap('n', '<leader>j', function() require('plugin.term').focus() end,
  { silent = true, desc = 'Focus persistent terminal' })


-- to qf, TODO: Add dynamic line number and edit capatility
keymap('n', '<leader>hq', function()
  local list = vim.fn.argv()
  if #list > 0 then
    local qf_items = {}
    for _, filename in ipairs(list) do
      table.insert(qf_items, {
        filename = filename,
        lnum = 1,
        text = filename
      })
    end
    vim.fn.setqflist(qf_items, 'r')
    vim.cmd.copen()
  end
end, { silent = true, desc = "Show args in qf" })

-- assign to each number the arg
for i = 1, 9 do
  keymap('n', '<leader>' .. i, "<CMD>argu " .. i .. "<CR>", { silent = true, desc = "Go to arg " .. i })
  keymap('n', '<leader>h' .. i, "<CMD>" .. i - 1 .. "arga<CR>", { silent = true, desc = "Add current to arg " .. i })
  keymap('n', '<leader>D' .. i, "<CMD>" .. i .. "argd<CR>", { silent = true, desc = "Delete current arg" })
end
