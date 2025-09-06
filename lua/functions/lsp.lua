local M = {}

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
    local vl_new_config = not vim.diagnostic.config().virtual_lines
    local vt_new_config
    if type(vim.diagnostic.config().virtual_text) == 'table' and vl_new_config then
      vt_new_config = false
    end
    vim.diagnostic.config({ virtual_lines = vl_new_config, virtual_text = vt_new_config })
  end, { desc = "Toggle Virtual Lines" })

  keymap('n', 'gL', function()
    ---@type boolean | table
    local vt_new_config = not vim.diagnostic.config().virtual_text
    if vt_new_config then
      vt_new_config = _virtual_text
    end
    vim.diagnostic.config({ virtual_text = vt_new_config })
  end, { desc = "Toggle Virtual Text" })

  keymap('n', 'K', function() vim.lsp.buf.hover { border = _border } end, opts("Show hover"))
  keymap('n', '<C-e>', function() vim.lsp.buf.signature_help { border = _border } end, opts("Show signature help"))
  keymap('n', 'gs', require 'telescope.builtin'.lsp_document_symbols, opts("Show document symbols"))
  keymap('n', 'gS', require 'telescope.builtin'.lsp_workspace_symbols, opts("Show workspace symbols"))
  keymap('n', 'g=', function() vim.lsp.buf.format { async = true } end, opts("Format document"))
  keymap('n', '<leader>e', vim.diagnostic.open_float, { desc = "View diagnostic in a float windows" })
  keymap('n', '<leader>]', function() vim.diagnostic.jump({ count = 1, float = true }) end,
    { desc = "Go to next diagnostic" })
  keymap('n', '<leader>[', function() vim.diagnostic.jump({ count = -1, float = true }) end,
    { desc = "Go to previous diagnostic" })
  keymap('n', 'g\\', require 'telescope.builtin'.diagnostics, opts("Show diagnostics"))
end


M.setup_ltex = function(bufnr)
  -- Latex config
  local spelling_fts = { 'markdown', 'tex', 'plaintext', 'ltex', 'text', 'gitcommit' }
  local ft = vim.api.nvim_get_option_value('filetype', { buf = bufnr })

  if not vim.tbl_contains(spelling_fts, ft) then
    return
  end

  -- Git commit messages should not have uppercase sentence start
  if ft == 'gitcommit' then
    local ltex_config = vim.lsp.get_clients({ name = "ltex_plus" })[1].config.settings
    if ltex_config == nil then
      vim.notify("ltex config not found", vim.log.levels.INFO)
      return
    end
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


  local ok, ltex = pcall(vim.lsp.get_clients, { name = "ltex_plus" })
  local ltex_config

  if ok and ltex[1] then
    ltex_config = ltex[1].config.settings
  end

  if ltex_config ~= nil then
    -- Setup language for spell checking
    local function change_ltex_config(language)
      if language == "en" then
        language = "en-US"
      end

      ---@diagnostic disable-next-line: inject-field
      ltex_config.ltex.language = language
      vim.lsp.buf_notify(0, "workspace/didChangeConfiguration", {
        settings = ltex_config
      })
      vim.notify("Changed ltex language to " .. language, vim.log.levels.INFO)
    end

    (function()
      local language = ltex_config.ltex.language or "en-US"
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
    end)()

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
        vim.lsp.buf_notify(0, "workspace/didChangeConfiguration", {
          settings = ltex_config
        })
      end, {
        nargs = 0,
      })

    vim.keymap.set({ "n", "x" }, "zg", function()
      local language = ltex_config.ltex.language or "en-US"
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
      vim.lsp.buf_notify(0, "workspace/didChangeConfiguration", { settings = ltex_config })
    end, { desc = "󰓆 Add Word", buffer = true })
  end
end

M.on_attach = function(client, bufnr)
  if client == nil then
    return
  end
  if client.server_capabilities.completionProvider then
    vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"
  end


  vim.diagnostic.config({
    underline = true,
    signs = true,
    float = {
      border = _border,
    },
    virtual_lines = false,
    update_in_insert = false,
    virtual_text = M.virtual_text
  })

  require 'lspconfig.ui.windows'.default_options = {
    border = M.border,
    focusable = true,
  }

  M.setup_ltex(bufnr)

  local e, lsp_signature = pcall(require, 'lsp_signature')

  if e then
    lsp_signature.on_attach({
      bind = true,
      handler_opts = {
        border = _border,
      },
      hint_enable = false,
      hint_prefix = " ",
      hint_scheme = "String",
      hi_parameter = "LspSignatureActiveParameter",
      max_height = 12,
      zindex = 200,
      transpancy = 90,
    })
  end

  M.set_keymaps(bufnr)
end

M.border = _border
M.virtual_text = _virtual_text
return M
