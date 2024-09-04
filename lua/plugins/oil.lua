return {
	"stevearc/oil.nvim",
	dependencies = { { "echasnovski/mini.icons", opts = {} } },
	opts = function(_, opts)
		opts.keys = {
			{ "<C-j>", false },
		}
		vim.keymap.set("n", "-", "<CMD>Oil<Cr>")
	end,
}
