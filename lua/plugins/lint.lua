return function(use)
	use("mfussenegger/nvim-lint")

	-- Configuración de nvim-lint
	require("lint").linters_by_ft = {
		python = { "pylint" },
		javascript = { "eslint" },
	}
end
