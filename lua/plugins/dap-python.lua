return {
	"mfussenegger/nvim-dap-python",
  -- stylua: ignore
  keys = {
    { "<leader>dPt", function() require('dap-python').test_method() end, desc = "Debug Method", ft = "python" },
    { "<leader>dPc", function() require('dap-python').test_class() end, desc = "Debug Class", ft = "python" },
  },
	config = function()
		require("dap-python").setup("python")
		-- If using the above, then `python -m debugpy --version`
		-- must work in the shell
	end,
}
