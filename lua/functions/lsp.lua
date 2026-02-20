local utils = require 'functions.utils'
local M = {}

---Locate the root directory and optionally enable the LSP
---only for determinated projects
---Allowed opts for projects:
--- - projects  -- Included projects
--- - excluded_projects
---@param markers string[]
---@param opts table?
---@return function
M.root_dir = function(markers, opts)
  return function(bufnr, on_dir)
    opts = opts or {}
    local cwd = vim.fn.getcwd()
    local bufpath = vim.api.nvim_buf_get_name(bufnr)

    local function search_upward(dir)
      -- Check current directory for markers
      for _, marker in ipairs(markers) do
        local marker_path = vim.fs.joinpath(dir, marker)
        if vim.fn.filereadable(marker_path) == 1 or vim.fn.isdirectory(marker_path) == 1 then
          return dir
        end
      end

      -- Go up one level
      local parent = vim.fs.dirname(dir)
      if parent == cwd:match("(.*)/.-$") then -- Reached cwd
        return nil
      end

      return search_upward(parent)
    end

    local root = search_upward(bufpath)
    -- If projects are passed, match that is in an allowed project
    if root then
      -- Check for included projects
      if opts.projects then
        for _, project in ipairs(opts.projects) do
          if cwd:find(utils.safe_pattern(project) .. "$") then
            on_dir(root)
          end
        end
      end

      -- Check for excluded projects
      if opts.excluded_projects then
        for _, project in ipairs(opts.excluded_projects) do
          if cwd:find(utils.safe_pattern(project) .. "$") then
            return -- Disabled
          end
        end
      end
    end

    -- Default is enabled if is not included in a list
    if not opts.projects then
      on_dir(root)
    end
  end
end

M.search_python_path = function()
  return vim.system({ "which", "python" }):wait().stdout:gsub('\n', '') or
      vim.system({ "which", "python3" }):wait().stdout:gsub('\n', '')
end

local _border = "single"
local _virtual_text = {
  spacing = 4,
  prefix = "",
}

M.set_keymaps = function(bufnr)
  local keymap = vim.keymap.set
  local opts = function(desc)
    return { buffer = bufnr, noremap = true, silent = true, desc = desc }
  end

  keymap('n', 'gD', vim.lsp.buf.declaration, opts("Go to declaration"))
  keymap('n', 'gd', vim.lsp.buf.definition, opts("Go to definition"))
  keymap('n', 'gi', vim.lsp.buf.implementation, opts("Go to implementation"))
  keymap('n', 'gr', vim.lsp.buf.references, opts("Go to references"))
  keymap('n', 'gt', vim.lsp.buf.type_definition, opts("Go to type definition"))
  keymap('n', 'gn', vim.lsp.buf.rename, opts("Rename symbol"))
  keymap('n', 'ga', vim.lsp.buf.code_action, opts("Code action"))

  keymap('n', 'gK', function()
    ---@type boolean
    local vl_new_config = not vim.diagnostic.config().virtual_lines
    ---@type table | boolean
    local vt_new_config = false
    if not vim.diagnostic.config().virtual_text and not vl_new_config then
      vt_new_config = _virtual_text
    end
    vim.diagnostic.config({ virtual_lines = vl_new_config, virtual_text = vt_new_config })
  end, { desc = "Toggle Virtual Lines" })

  keymap('n', 'gL', function()
    ---@type boolean | table
    local vt_new_config = not type(vim.diagnostic.config().virtual_text) == "table"
    if vt_new_config then
      vt_new_config = _virtual_text
    end
    vim.diagnostic.config({ virtual_text = vt_new_config })
  end, { desc = "Toggle Virtual Text" })

  keymap('n', 'K', function() vim.lsp.buf.hover { border = _border } end, opts("Show hover"))
  keymap('n', '<C-e>', function() vim.lsp.buf.signature_help { border = _border } end, opts("Show signature help"))
  keymap('n', 'g=', function() vim.lsp.buf.format { async = true } end, opts("Format document"))
  keymap('n', '<leader>e', vim.diagnostic.open_float, { desc = "View diagnostic in a float windows" })
  keymap('n', '<leader>]', function() vim.diagnostic.jump({ count = 1, float = true }) end,
    { desc = "Go to next diagnostic" })
  keymap('n', '<leader>[', function() vim.diagnostic.jump({ count = -1, float = true }) end,
    { desc = "Go to previous diagnostic" })
end


---@param client vim.lsp.Client
---@param bufnr integer
M.setup_ltex = function(client, bufnr)
  -- Latex config
  local spelling_fts = { 'markdown', 'tex', 'plaintext', 'ltex', 'text', 'gitcommit' }
  local ft = vim.api.nvim_get_option_value('filetype', { buf = bufnr })

  if not vim.tbl_contains(spelling_fts, ft) then
    return
  end

  local ltex_config = client.config.settings
  if not ltex_config then
    return
  end
  -- Git commit messages should not have uppercase sentence start
  if ft == 'gitcommit' then
    ---@diagnostic disable-next-line: inject-field
    ltex_config.ltex.disabledRules = {
      ["en-US"] = {
        "UPPERCASE_SENTENCE_START",
      },
      ["es"] = {
        "UPPERCASE_SENTENCE_START",
      }
    }
  end

  -- Setup language for spell checking
  local function change_ltex_config(language)
    if language == "en" then
      language = "en-US"
    end

    ---@diagnostic disable-next-line: inject-field
    ltex_config.ltex.language = language
    client:notify("workspace/didChangeConfiguration", {
      settings = ltex_config
    })
    vim.notify("Changed ltex language to " .. language, vim.log.levels.INFO)

    language = ltex_config.ltex.language or "en-US"
    local vim_lang = language

    if language == "en-US" then
      vim_lang = "en"
    end

    local file = vim.fn.stdpath("config") .. "/spell/" .. vim_lang .. ".utf-8.add"
    if vim.fn.filereadable(file) == 0 then
      return
    end

    local words = vim.fn.readfile(file)

    ltex_config.ltex.dictionary = ltex_config.ltex.dictionary or {}
    ltex_config.ltex.dictionary[language] = ltex_config.ltex.dictionary[language] or {}
    ltex_config.ltex.dictionary[language] = words

    vim.api.nvim_buf_create_user_command(
      bufnr,
      "LtexLang",
      function(args)
        if args.args == nil or #args.args == 0 then
          vim.notify("No language provided", vim.log.levels.ERROR)
          vim.notify("Usage: LtexLang <language>", vim.log.levels.INFO)
          vim.notify("Passed args: " .. vim.inspect(args.args), vim.log.levels.INFO)
          return
        end
        change_ltex_config(args.args)
      end, {
        nargs = 1,
      })

    vim.api.nvim_buf_create_user_command(
      bufnr,
      "LtexToggleCheck",
      function()
        if ltex_config.ltex.enabled == nil or #ltex_config.ltex.enabled == 0 then
          ltex_config.ltex.enabled = vim.g.ltex_enabled
          vim.notify("Enabled ltex diagnostics check", vim.log.levels.INFO)
        else
          vim.g.ltex_enabled = ltex_config.ltex.enabled
          ltex_config.ltex.enabled = {}
          vim.notify("Disabled ltex diagnostics check", vim.log.levels.INFO)
        end
        client:notify("workspace/didChangeConfiguration", {
          settings = ltex_config
        })
      end, {
        nargs = 0,
      })

    vim.keymap.set({ "n", "x" }, "zg", function()
      language = ltex_config.ltex.language or "en-US"
      local vim_lang = language

      if language == "en-US" then
        vim_lang = "en"
      end

      local file = vim.fn.stdpath("config") .. "/spell/" .. vim_lang .. ".utf-8.add"

      vim.opt.spelllang = vim_lang
      vim.opt.spellfile = file

      local current_words = {}

      if vim.fn.filereadable(file) == 1 then
        current_words = vim.fn.readfile(file)
      end

      local word

      if vim.tbl_contains(current_words, word) then
        vim.notify("Word already added to dictionary", vim.log.levels.INFO)
        return
      end

      if vim.fn.mode() == "n" then
        word = vim.fn.expand("<cword>")
        vim.cmd.normal { 'zg', bang = true }
      else
        vim.cmd.normal { 'zggv"zy', bang = true }
        word = vim.fn.getreg("z")
      end

      if not ltex_config.ltex.dictionary then
        ltex_config.ltex.dictionary = {}
        ltex_config.ltex.dictionary[language] = current_words
      end

      if ltex_config.ltex.dictionary[language] == nil then
        ltex_config.ltex.dictionary[language] = current_words
      end

      table.insert(ltex_config.ltex.dictionary[language], word)
      client:notify("workspace/didChangeConfiguration", { settings = ltex_config })
    end, { desc = "󰓆 Add Word", buffer = true })
  end
end

M.on_attach = function(client, bufnr)
  if client == nil then
    return
  end
  if client.server_capabilities and client:supports_method('textDocument/completion') then
    vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"
  end

  if client and client:supports_method('textDocument/documentColor') then
    vim.lsp.document_color.enable(true, bufnr, { style = 'background' })
  end

  if client.name and client.name:find("^ltex") then
    M.setup_ltex(client, bufnr)
  end

  -- Less highlight bullshit from the LSP
  -- https://www.reddit.com/r/neovim/comments/143efmd/is_it_possible_to_disable_treesitter_completely/
  client.server_capabilities.semanticTokensProvider = nil

  M.set_keymaps(bufnr)
end

M.get_active_clients_names = function()
  local clients = vim.lsp.get_clients()
  local names = {}
  for _, client in ipairs(clients) do
    table.insert(names, client.name)
  end
  return names
end

---Get the client from the name
---@param name string
---@return vim.lsp.Client?
M.get_client_from_name = function(name)
  local clients = vim.lsp.get_clients({ name = name })
  return clients[1]
end

M.border = _border
M.virtual_text = _virtual_text
return M
