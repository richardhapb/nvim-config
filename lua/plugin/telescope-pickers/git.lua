local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local previewers = require('telescope.previewers')
local conf = require('telescope.config').values
local make_entry = require('telescope.make_entry')
local utils = require('telescope.utils')
local strings = require "plenary.strings"
local entry_display = require('telescope.pickers.entry_display')

local lutils = require('functions.utils')

local M = {}

local git_diff_name_only = function(prompt_bufnr)
  local cwd = action_state.get_current_picker(prompt_bufnr).cwd
  local selection = action_state.get_selected_entry()
  if selection == nil then
    vim.notify("No branch selected", vim.log.levels.ERROR)
    return
  end
  local branch = selection.value

  actions.close(prompt_bufnr)
  local res, ret, _ = utils.get_os_command_output({ "git", "diff", branch, "--name-only" }, cwd)

  if ret == 0 then
    vim.notify("Git diff made successfully", vim.log.levels.INFO)
  else
    vim.notify("Git diff failed", vim.log.levels.ERROR)
    return
  end

  if #res == 0 or res == nil then
    vim.notify("No changes", vim.log.levels.INFO)
    return
  end

  -- Verify if the buffer already exists
  local buffer = vim.fn.bufnr("Git diff: " .. branch)
  if buffer == -1 then
    buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buffer, "Git diff: " .. branch)
  end

  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, res)
  vim.api.nvim_set_current_buf(buffer)

  vim.keymap.set('n', '<CR>', function() lutils.git_curr_line_diff_split(branch, buffer) end, { buffer = buffer })
  vim.keymap.set('n', 'R', function() lutils.git_restore_curr_line(branch) end, { buffer = buffer })
end

M.git_branches_diff = function(opts)
  opts = opts or {}
  local format = "%(HEAD)"
      .. "%(refname)"
      .. "%(authorname)"
      .. "%(upstream:lstrip=2)"
      .. "%(committerdate:format-local:%Y/%m/%d %H:%M:%S)"
  local output = utils.get_os_command_output({ "git", "for-each-ref", "--perl", "--format", format, opts.pattern },
    opts.cwd)
  local results = {}
  local widths = {
    name = 0,
    authorname = 0,
    upstream = 0,
    committerdate = 0,
  }
  local unescape_single_quote = function(v)
    return string.gsub(v, "\\([\\'])", "%1")
  end

  local parse_line = function(line)
    local fields = vim.split(string.sub(line, 2, -2), "''", { plain = true })
    local entry = {
      head = fields[1],
      refname = unescape_single_quote(fields[2]),
      authorname = unescape_single_quote(fields[3]),
      upstream = unescape_single_quote(fields[4]),
      committerdate = fields[5],
    }
    local prefix
    if vim.startswith(entry.refname, "refs/remotes/") then
      prefix = "refs/remotes/"
    elseif vim.startswith(entry.refname, "refs/heads/") then
      prefix = "refs/heads/"
    else
      return
    end
    local index = 1
    if entry.head ~= "*" then
      index = #results + 1
    end

    entry.name = string.sub(entry.refname, string.len(prefix) + 1)
    for key, value in pairs(widths) do
      widths[key] = math.max(value, strings.strdisplaywidth(entry[key] or ""))
    end
    if string.len(entry.upstream) > 0 then
      widths.upstream_indicator = 2
    end
    table.insert(results, index, entry)
  end
  for _, line in ipairs(output) do
    parse_line(line)
  end
  if #results == 0 then
    return
  end

  local displayer = entry_display.create {
    separator = " ",
    items = {
      { width = 1 },
      { width = widths.name },
      { width = widths.authorname },
      { width = widths.upstream_indicator },
      { width = widths.upstream },
      { width = widths.committerdate },
    },
  }
  local make_display = function(entry)
    return displayer {
      { entry.head },
      { entry.name, "TelescopeResultsIdentifier" },
      { entry.authorname },
      { string.len(entry.upstream) > 0 and "=>" or "" },
      { entry.upstream, "TelescopeResultsIdentifier" },
      { entry.committerdate },
    }
  end

  pickers.new(opts, {
    prompt_title = 'Git Branches Diff',
    finder = finders.new_table {
      results = results,
      entry_maker = function(entry)
        entry.value = entry.name
        entry.ordinal = entry.name
        entry.display = make_display
        return make_entry.set_default_entry_mt(entry, opts)
      end,
    },
    sorter = conf.generic_sorter(opts),
    entry_maker = function(entry)
      entry.value = entry.name
      entry.ordinal = entry.name
      entry.display = make_display

      return make_entry.set_default_entry_mt(entry, opts)
    end,
    attach_mappings = function(_, map)
      actions.select_default:replace(git_diff_name_only)
      map({ "i", "n" }, "<c-t>", actions.git_track_branch)
      map({ "i", "n" }, "<c-r>", actions.git_rebase_branch)
      map({ "i", "n" }, "<c-a>", actions.git_create_branch)
      map({ "i", "n" }, "<c-s>", actions.git_switch_branch)
      map({ "i", "n" }, "<c-d>", actions.git_delete_branch)
      map({ "i", "n" }, "<c-y>", actions.git_merge_branch)
      return true
    end,
    previewer = previewers.git_commit_diff_to_head.new(opts),
  }):find()
end

return M
