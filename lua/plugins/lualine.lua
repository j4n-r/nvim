local colors = {
	-- Base Colors
	base = "#191724",
	surface = "#1f1d2e",
	overlay = "#26233a",

	-- Text Colors
	muted = "#6e6a86",
	subtle = "#908caa",
	text = "#e0def4",

	-- Accent Colors
	love = "#eb6f92",
	gold = "#f6c177",
	rose = "#ebbcba",
	pine = "#31748f",
	foam = "#9ccfd8",
	iris = "#c4a7e7",

	null = nil,

	-- Additional Colors
	highlight_low = "#21202e",
	highlight_med = "#403d52",
	highlight_high = "#524f67",
}
return {
	{
		"nvim-lualine/lualine.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		opts = {
			options = {
				theme = {
					normal = {
						a = { bg = colors.iris, fg = colors.base, gui = "bold" },
						b = { bg = colors.overlay, fg = colors.iris },
						c = { bg = colors.null, fg = colors.text },
					},
					insert = {
						a = { bg = colors.foam, fg = colors.base, gui = "bold" },
						b = { bg = colors.overlay, fg = colors.foam },
						c = { bg = colors.null, fg = colors.text },
					},
					visual = {
						a = { bg = colors.rose, fg = colors.base, gui = "bold" },
						b = { bg = colors.overlay, fg = colors.rose },
						c = { bg = colors.null, fg = colors.text },
					},
					replace = {
						a = { bg = colors.pine, fg = colors.base, gui = "bold" },
						b = { bg = colors.overlay, fg = colors.pine },
						c = { bg = colors.null, fg = colors.text },
					},
					command = {
						a = { bg = colors.love, fg = colors.base, gui = "bold" },
						b = { bg = colors.overlay, fg = colors.love },
						c = { bg = colors.null, fg = colors.text },
					},
					inactive = {
						a = { bg = colors.base, fg = colors.muted, gui = "bold" },
						b = { bg = colors.base, fg = colors.muted },
						c = { bg = colors.null, fg = colors.muted },
					},
				},
				icons_enabled = true,
				-- theme = "auto",
				component_separators = { left = "", right = "" },
				section_separators = { left = "", right = "" },
				disabled_filetypes = {
					statusline = {},
					winbar = {},
				},
				ignore_focus = {},
				always_divide_middle = true,
				globalstatus = false,
				refresh = {
					statusline = 1000,
					tabline = 1000,
					winbar = 1000,
				},
			},
			sections = {
				lualine_a = { "mode" },
				lualine_b = { "branch", "diff", "diagnostics" },
				lualine_c = { "filename" },
				lualine_x = { "encoding", "fileformat", "filetype" },
				lualine_y = { "progress" },
				lualine_z = { "location" },
			},
			inactive_sections = {
				lualine_a = {},
				lualine_b = {},
				lualine_c = { "filename" },
				lualine_x = { "location" },
				lualine_y = {},
				lualine_z = {},
			},
			tabline = {},
			winbar = {},
			inactive_winbar = {},
			extensions = {},
		},
	},
}
