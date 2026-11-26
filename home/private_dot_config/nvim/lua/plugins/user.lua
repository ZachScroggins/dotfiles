return {
  -- Theme: Catppuccin Mocha
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = { flavour = "mocha" },
  },
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "catppuccin-mocha" },
  },

  -- Formatters
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        -- ruff: apply lint fixes, sort imports, then format
        python = { "ruff_fix", "ruff_organize_imports", "ruff_format" },
      },
      formatters = {
        -- Project .prettierrc wins; otherwise use 100 cols
        prettier = {
          prepend_args = { "--config-precedence", "prefer-file", "--print-width", "100" },
        },
      },
    },
  },

  -- LSP formatters (e.g. "eslint: lsp" = ESLint --fix on save) go through conform. Its default
  -- lsp_format="fallback" skips the LSP whenever Prettier exists, so ESLint fixes never ran.
  -- "prefer" makes those calls use the LSP; Prettier still runs via LazyVim's conform formatter.
  {
    "neovim/nvim-lspconfig",
    opts = { format = { lsp_format = "prefer" } },
  },

  -- Extra parsers: CSS for Tailwind work; latex so snacks can render math in docs
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "css", "scss", "latex" } },
  },

  -- markdownlint disabled completely (linter and formatter)
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      opts.linters_by_ft = opts.linters_by_ft or {}
      opts.linters_by_ft.markdown = {}
    end,
  },
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.markdown = { "prettier" }
      opts.formatters_by_ft["markdown.mdx"] = { "prettier" }
    end,
  },

  -- Make sure the CLI tools are installed
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "ruff", "ty", "prettier", "eslint-lsp" } },
  },
}
