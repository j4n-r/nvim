return {
	"mxsdev/nvim-dap-vscode-js",
	dependencies = {
		"mfussenegger/nvim-dap",
		{
			"microsoft/vscode-js-debug",
			version = "1.x",
			build = "npm i && npm run compile vsDebugServerBundle && mv dist out",
		},
	},
	opts = function(_, opts)
		opts.adapters = { "pwa-node", "pwa-chrome", "pwa-msedge", "node-terminal", "pwa-extensionHost" } -- which adapters to register in nvim-dap
		opts.debugger_path = vim.fn.stdpath("data") .. "/lazy/vscode-js-debug"
		return opts
	end,
}
