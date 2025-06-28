return {
  "hrsh7th/nvim-cmp",
  dependencies = {
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-path",
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-git",
    "hrsh7th/cmp-cmdline",
    "L3MON4D3/LuaSnip",
    "saadparwaiz1/cmp_luasnip",
    "tailwind-tools",
    "onsails/lspkind-nvim",
    { "windwp/nvim-autopairs", opts = { check_ts = true } }
  },

  event = "VeryLazy",
  config = function()
    local cmp = require("cmp")
    local luasnip = require("luasnip")
    local cmp_autopairs = require "nvim-autopairs.completion.cmp"

    local icons = {
      Text = "",
      Method = "",
      Function = "󰊕",
      Constructor = "",
      Field = "",
      Variable = "",
      Class = "",
      Interface = "ﰮ",
      Module = "",
      Property = "",
      Unit = "",
      Value = "",
      Enum = "",
      Keyword = "",
      Snippet = "",
      Color = "",
      File = "",
      Reference = "",
      Folder = "",
      EnumMember = "",
      Constant = "A",
      Struct = "",
      Event = "",
      Operator = "",
      TypeParameter = "T",
    }

    cmp.setup({
      snippet = {
        expand = function(args)
          luasnip.lsp_expand(args.body)
        end
      },

      mapping = {
        ["<C-u>"] = cmp.mapping.scroll_docs(-4),
        ["<C-d>"] = cmp.mapping.scroll_docs(4),
        ["<C-e>"] = cmp.mapping.abort(),
        ["<C-k>"] = cmp.mapping.complete(),
        ["<C-n>"] = cmp.mapping.select_next_item(),
        ["<C-p>"] = cmp.mapping.select_prev_item(),
        ["<C-y>"] = cmp.mapping.confirm {
          behavior = cmp.ConfirmBehavior.Insert,
          select = true
        },
      },

      sources = cmp.config.sources {
        { name = "lazydev",        group_index = 0, },
        { name = "nvim_lsp" },
        { name = "markdown-render" },
        { name = "path" },
        { name = "luasnip" },
        { name = "buffer", }
      },

      window = {
        completion = {
          border = 'single'
        },
        documentation = {
          border = 'single',
          max_height = 100,
          max_width = 200,
        }
      },

      ---@diagnostic disable-next-line: missing-fields
      formatting = {
        format = function(_, vim_item)
          require("lspkind").cmp_format({
            before = require("tailwind-tools.cmp").lspkind_format
          })
          local kind_icon = icons[vim_item.kind] or ""
          vim_item.kind = string.format("%s %s", kind_icon, vim_item.kind)
          return vim_item
        end
      },

      experimental = { ghost_text = false },
      cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done { map_char = { tex = "" } }),

      cmp.setup.filetype('gitcommit', {
        sources = cmp.config.sources({
          { name = 'git' },
          { name = 'buffer' }
        })
      }),

      cmp.setup.cmdline(':', {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({
          { name = 'path' },
          { name = 'cmdline' }
        })
      }),

      cmp.setup.cmdline({ '/', '?' }, {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({
          { name = 'buffer' },
        })
      })
    })
  end
}
