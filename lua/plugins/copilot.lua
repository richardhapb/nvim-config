-- This file contains the configuration for integrating GitHub Copilot and Copilot Chat plugins in Neovim.

-- Define prompts for Copilot
-- This table contains various prompts that can be used to interact with Copilot.
local prompts = {
  Explain = "Please explain how the following code works.",
  Review = "Please review the following code and give me feedback.",
  Tests = "Generate unit tests for this code, focus in elegance and safety.",
  Refactor = "Please refactor the following code to improve its performance, elegance and readability.",
  FixCode = "Please fix the following code to make it work as intended.",
  FixError = "Please explain the error in the following text and provide a solution.",
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

-- Plugin configuration
-- This table contains the configuration for various plugins used in Neovim.
return {
  -- GitHub Copilot plugin
  { "github/copilot.vim" }, -- Load the GitHub Copilot plugin

  -- Which-key plugin configuration
  {
    "folke/which-key.nvim", -- Load the which-key plugin
    optional = true,        -- This plugin is optional
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
      model = 'claude-3.5-sonnet',
      context = nil,
      stick = "Any code that you generate should be elegant, performatic and rustacean.", -- Follow-Rust good practices
      mappings = {
        complete = { detail = "Use @<C-z> or /<C-z> for options.", insert = "<C-z>" },
        close = { normal = "q", insert = "<C-c>" },
        reset = { normal = "<C-x>", insert = "<C-x>" },
        submit_prompt = { normal = "<CR>", insert = "<C-b>" },
        accept_diff = { normal = "<C-y>", insert = "<C-y>" },
        yank_diff = { normal = "gmy" },
        show_diff = { normal = "gmd" },
        show_info = { normal = "gmp" },
        show_context = { normal = "gms" },
        show_help = { normal = "gmh" },
      },
      window = {
        layout = "float",
        width = 0.8,
        height = 0.8,
      }
    },
    config = function(_, opts)
      local chat = require("CopilotChat")
      local select = require("CopilotChat.select")

      -- Define custom prompts for commit messages
      opts.prompts.Commit = {
        prompt = "Write commit message for the change with commitizen convention",
        selection = select.gitdiff,
      }

      opts.prompts.CommitStaged = {
        prompt = "Write commit message for the change with commitizen convention",
        selection = function()
          return select.gitdiff()
        end,
      }

      chat.setup(opts)

      -- Create user commands for different chat modes
      vim.api.nvim_create_user_command("CopilotChatVisual", function(args)
        chat.ask(args.args, { selection = select.visual })
      end, { nargs = "*", range = true })

      vim.api.nvim_create_user_command("CopilotChatInline", function(args)
        chat.ask(args.args, {
          selection = select.visual,
          window = {
            layout = "float",
            relative = "cursor",
            width = 1,
            height = 0.4,
            row = 1,
          },
        })
      end, { nargs = "*", range = true })

      vim.api.nvim_create_user_command("CopilotChatBuffer", function(args)
        chat.ask(args.args, { selection = select.buffer })
      end, { nargs = "*", range = true })

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
        ":CopilotChatPrompt<cr>",
        desc = "CopilotChat - Prompt actions",
      },
      { "<leader>ae", "<cmd>CopilotChatExplain<cr>",       desc = "CopilotChat - Explain code" },
      { "<leader>at", "<cmd>CopilotChatTests<cr>",         desc = "CopilotChat - Generate tests" },
      { "<leader>ar", "<cmd>CopilotChatReview<cr>",        desc = "CopilotChat - Review code" },
      { "<leader>aR", "<cmd>CopilotChatRefactor<cr>",      desc = "CopilotChat - Refactor code" },
      { "<leader>an", "<cmd>CopilotChatBetterNamings<cr>", desc = "CopilotChat - Better Naming" },
      { "<leader>av", ":CopilotChatVisual ",               mode = "x",                           desc = "CopilotChat - Open in vertical split" },
      { "<leader>ax", ":CopilotChatInline<cr>",            mode = "x",                           desc = "CopilotChat - Inline chat" },
      {
        "<leader>ai",
        function()
          local input = vim.fn.input("Ask Copilot: ")
          if input ~= "" then
            vim.cmd("CopilotChat " .. input)
          end
        end,
        desc = "CopilotChat - Ask input",
      },
      { "<leader>am", "<cmd>CopilotChatCommit<cr>",        desc = "CopilotChat - Generate commit message for all changes" },
      {
        "<leader>aM",
        "<cmd>CopilotChatCommitStaged<cr>",
        desc = "CopilotChat - Generate commit message for staged changes",
      },
      {
        "<leader>aq",
        function()
          local input = vim.fn.input("Quick Chat: ")
          if input ~= "" then
            vim.cmd("CopilotChatBuffer " .. input)
          end
        end,
        desc = "CopilotChat - Quick chat",
      },
      { "<leader>ad", "<cmd>CopilotChatDebugInfo<cr>",     desc = "CopilotChat - Debug Info" },
      { "<leader>af", "<cmd>CopilotChatFixDiagnostic<cr>", desc = "CopilotChat - Fix Diagnostic" },
      { "<leader>al", "<cmd>CopilotChatReset<cr>",         desc = "CopilotChat - Clear buffer and chat history" },
      { "<leader>av", "<cmd>CopilotChatToggle<cr>",        desc = "CopilotChat - Toggle" },
      { "<leader>a?", "<cmd>CopilotChatModels<cr>",        desc = "CopilotChat - Select Models" },
    },
  },
}
