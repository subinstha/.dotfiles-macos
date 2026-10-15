return {
	{
		"nvimtools/none-ls.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"jay-babu/mason-null-ls.nvim",
			"nvimtools/none-ls-extras.nvim",
		},
		config = function()
			local null_ls = require("null-ls")

			null_ls.setup({
				sources = {
					-- Lua
					null_ls.builtins.formatting.stylua,

					-- JavaScript/TypeScript/HTML/CSS/JSX (Prettier)
					null_ls.builtins.formatting.prettierd.with({
						filetypes = {
							"javascript",
							"javascriptreact",
							"typescript",
							"typescriptreact",
							"html",
							"css",
							"scss",
							"json",
							"yaml",
							"markdown",
						},
					}),
					require("none-ls.diagnostics.eslint_d"),

					-- Python
					null_ls.builtins.formatting.black,
					null_ls.builtins.formatting.isort,

					-- Ruby
					null_ls.builtins.formatting.rubocop,
					null_ls.builtins.diagnostics.rubocop,

					-- Rust: formatting (rustfmt) and linting (clippy) come from rust_analyzer
				},
			})

			-- Format keybinding
			vim.keymap.set("n", "<leader>fi", function()
				vim.lsp.buf.format({ async = true })
			end, { desc = "Format file" })
		end,
	},
	{
		"jay-babu/mason-null-ls.nvim",
		dependencies = {
			"mason-org/mason.nvim",
			"nvimtools/none-ls.nvim",
		},
		config = function()
			require("mason-null-ls").setup({
				ensure_installed = {
					"stylua",
					"prettierd",
					"eslint_d",
					"black",
					"isort",
					"rubocop",
				},
				automatic_installation = true,
			})
		end,
	},
}
