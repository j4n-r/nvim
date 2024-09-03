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
require("config.lazy")

vim.cmd.colorscheme("rose-pine")

-- set notify as standart
vim.notify = require("notify")

-- Set transparent background
vim.cmd([[
  hi Normal guibg=NONE ctermbg=NONE
]])
