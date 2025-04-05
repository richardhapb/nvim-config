-- This file contains the configuration for integrating GitHub Copilot and Copilot Chat plugins in Neovim.

-- Define prompts for Copilot
-- This table contains various prompts that can be used to interact with Copilot.
local prompts = {
  Explain = "Please explain how the following code works.",
  Review = "Please review the following code and give me feedback.",
  Tests = "Generate unit tests for this code, focus in elegance and safety.",
  Refactor = "Please refactor the following code to improve its performance, elegance and readability.",
  FixCode = "Please fix the following code to make it work as intended.",
  FixError = "Please explain the error in the following code and provide a solution.",
  BetterNamings = "Please provide better names for the following code.",
  Documentation = "Please provide documentation for the following code.",
  Docs = "Please provide documentation for the following code in the language's style.",
  RustDocs = "Please provide documentation for the following code in Rust crates style.",
  DocumentationForGithub = "Please provide documentation for the following code ready for GitHub using markdown.",
  CreateAPost =
  "Please provide documentation for the following code to post it in social media, like Linkedin, it has be deep, well explained and easy to understand. Also do it in a fun and engaging way.",
  SwaggerApiDocs = "Please provide documentation for the following API using Swagger.",
  Summarize = "Please summarize the following text.",
  Spelling =
  "Please correct any grammar and spelling errors in the following text. Focus on readability and clarity in a straightforward manner.",
  TranslateToEnglish = "Please translate the following text to English.",
  TranslateToSpanish = "Please translate the following text to Spanish.",
  Concise = "Please rewrite the following text to make it more concise.",
}

---Ask to copilot with custom context, and use callback if it is provided
---@param callback? function
---@param opts? table
local function custom_visual_context(callback, opts)
  opts = opts or {}
  local utils = require 'functions.utils'
  local cutils = require 'CopilotChat.utils'
  local bufnr = vim.api.nvim_get_current_buf()
  local visual_selection = utils.get_visual_selection()
  local start_line, end_line = 1, vim.api.nvim_buf_line_count(bufnr)
  if visual_selection ~= "" then
    start_line, _, end_line = unpack(utils.get_text_range(bufnr, visual_selection))
  end

  local config = {
    selection = function()
      return {
        content = visual_selection,
        start_line = start_line,
        end_line = end_line,
        filename = cutils.filepath(vim.api.nvim_buf_get_name(bufnr)),
        filetype = vim.api.nvim_get_option_value('filetype', { buf = bufnr }),
        bufnr = bufnr,
        diagnostics = cutils.diagnostics(bufnr, start_line, end_line)
      }
    end,
    context = "buffer",
    highlight_selection = true
  }

  config = vim.tbl_deep_extend("force", config, opts)

  ---Ask to copilot with additional text
  ---@param custom_prompt string?
  local ask_to_copilot = function(custom_prompt)
    if custom_prompt then
      require 'CopilotChat'.ask(custom_prompt, config)
    else
      require 'CopilotChat'.select_prompt(config)
    end
  end

  if callback then
    callback(ask_to_copilot)
  else
    ask_to_copilot()
  end
end

---Custom prompt in a floating window with context
---@param ask_to_copilot function
local function temp_float_ask_buffer(ask_to_copilot)
  local ch = require 'CopilotChat'
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("filetype", "copilot-chat", { buf = buf })

  -- Enable the completion for context and model selection
  -- in the floating window
  vim.api.nvim_create_autocmd("CursorMovedI", {
    group = vim.api.nvim_create_augroup("CopilotComplete", { clear = true }),
    buffer = buf,
    callback = function()
      ch.trigger_complete(false)
    end
  })


  local width = math.floor(vim.o.columns * 0.6)
  local height = math.floor(vim.o.lines * 0.2)

  local row = -height - 2
  local col = 0

  local win_config = {
    relative = 'cursor',
    border = 'rounded',
    focusable = true,
    row = row,
    col = col,
    width = width,
    height = height,
    style = 'minimal',
    title = "Custom prompt"
  }

  local win = vim.api.nvim_open_win(buf, true, win_config)

  vim.wo[win].wrap = true
  vim.cmd 'startinsert'

  local function send_prompt()
    local add_prompt = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
    vim.cmd 'stopinsert'
    vim.cmd 'q!'
    if add_prompt and add_prompt ~= '' then
      ask_to_copilot(add_prompt)
    end
  end

  vim.keymap.set('n', '<CR>', send_prompt, { buffer = buf })
  vim.keymap.set('i', '<C-s>', send_prompt, { buffer = buf })

  vim.keymap.set('n', 'q', "<CMD>q!<CR>", { buffer = buf, silent = true })
end

return {
  -- GitHub Copilot plugin
  { "github/copilot.vim" },

  -- Which-key plugin configuration
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>a", group = "ai" },
        { "gm",        group = "+Copilot chat" },
        { "gmh",       desc = "Show help" },
        { "gmd",       desc = "Show diff" },
        { "gmp",       desc = "Show system prompt" },
        { "gms",       desc = "Show selection" },
        { "gmy",       desc = "Yank diff" },
      },
    },
  },

  -- Copilot Chat plugin configuration
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "main",
    dependencies = {
      { "nvim-telescope/telescope.nvim" },
      { "nvim-lua/plenary.nvim" },
    },
    opts = {
      question_header = "## Richard ", -- Header for user questions
      answer_header = "## Copilot ",   -- Header for Copilot answers
      error_header = "## Error ",      -- Header for errors
      prompts = prompts,
      auto_follow_cursor = false,
      show_help = false,
      show_auto_complete = true,
      show_diff = true,
      model = 'claude-3.7-sonnet',
      context = nil,
      selection = nil,
      stick = "Any code that you generate should be elegant, performatic and idiomatic.",
      mappings = {
        complete = { detail = "Use @<C-z> or /<C-z> for options.", insert = "<C-z>" },
        close = { normal = "q", insert = "<C-c>" },
        reset = { normal = "<C-x>", insert = "<C-x>" },
        submit_prompt = { normal = "<CR>", insert = "<C-s>" },
        accept_diff = { normal = "<C-y>", insert = "<C-y>" },
        yank_diff = { normal = "gmy" },
        show_diff = { normal = "gmd" },
        show_info = { normal = "gmp" },
        show_context = { normal = "gms" },
        show_help = { normal = "gmh" },
      },
      window = {
        layout = "horizontal",
        width = 1,
        height = 0.35,
      }
    },
    config = function(_, opts)
      local chat = require("CopilotChat")
      chat.setup(opts)

      -- Set buffer-specific options when entering Copilot buffers
      vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "copilot-*",
        callback = function()
          vim.opt_local.relativenumber = true
          vim.opt_local.number = true

          local ft = vim.bo.filetype
          if ft == "copilot-chat" then
            vim.bo.filetype = "markdown"
          end
        end,
      })
    end,
    event = "VeryLazy",
    keys = {
      {
        "<leader>ap",
        mode = { "n", "v" },
        custom_visual_context,
        desc = "CopilotChat - Prompt actions",
      },
      { "<leader>ae", "<cmd>CopilotChatExplain<cr>",                               desc = "CopilotChat - Explain code" },
      { "<leader>at", "<cmd>CopilotChatTests<cr>",                                 desc = "CopilotChat - Generate tests" },
      { "<leader>ar", "<cmd>CopilotChatReview<cr>",                                desc = "CopilotChat - Review code" },
      { "<leader>aR", "<cmd>CopilotChatRefactor<cr>",                              desc = "CopilotChat - Refactor code" },
      { "<leader>an", "<cmd>CopilotChatBetterNamings<cr>",                         desc = "CopilotChat - Better Naming" },
      { "<leader>av", function() custom_visual_context(temp_float_ask_buffer) end, mode = "x",                           desc = "CopilotChat - Horizontal chat" },
      {
        "<leader>ax",
        function()
          custom_visual_context(temp_float_ask_buffer, {
            window = {
              layout = "float",
              relative = "cursor",
              width = 1,
              height = 0.4,
              row = 1,
            },
          })
        end,
        mode = "x",
        desc = "CopilotChat - Inline chat"
      },

      {
        "<leader>ai",
        function()
          temp_float_ask_buffer(function (prompt) require'CopilotChat'.ask(prompt, { context = nil }) end)
        end,
        desc = "CopilotChat - Ask input",
      },
      { "<leader>am", "<cmd>CopilotChatCommit<cr>",        desc = "CopilotChat - Generate commit message for all changes" },
      { "<leader>ad", "<cmd>CopilotChatDebugInfo<cr>",     desc = "CopilotChat - Debug Info" },
      { "<leader>af", "<cmd>CopilotChatFixDiagnostic<cr>", desc = "CopilotChat - Fix Diagnostic" },
      { "<leader>al", "<cmd>CopilotChatReset<cr>",         desc = "CopilotChat - Clear buffer and chat history" },
      { "<leader>av", "<cmd>CopilotChatToggle<cr>",        desc = "CopilotChat - Toggle" },
      { "<leader>a?", "<cmd>CopilotChatModels<cr>",        desc = "CopilotChat - Select Models" },
    },
  },
}
