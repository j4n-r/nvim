require("config.lazy")
------------- Autocommands ----------------------
-- Highlight when yanking (copying) text
--  Try it with yap in normal mode
--  See :help vim.highlight.on_yank()
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
	callback = function()
		vim.highlight.on_yank()
	end,
})
------------- Import -------------------------
--- import lazy

vim.cmd.colorscheme("rose-pine")

-- set notify as standart
vim.notify = require("notify")

-- Set transparent background
vim.cmd([[
  hi Normal guibg=NONE ctermbg=NONE
]])

-- initialize global var to false -> nvim-cmp turned off per default
vim.g.cmptoggle = false

local cmp = require("cmp")
cmp.setup({
	enabled = function()
		return vim.g.cmptoggle
	end,
})
vim.keymap.set("n", "<leader>ac", "<cmd>lua vim.g.cmptoggle = not vim.g.cmptoggle<CR>", { desc = "toggle nvim-cmp" })

vim.g.firenvim_config = {
	globalSettings = { alt = "all" },
	localSettings = {
		[".*"] = {
			cmdline = "neovim",
			content = "text",
			priority = 0,
			selector = "textarea",
			takeover = "never",
		},
	},
}
