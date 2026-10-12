-- Unity: o Unity abre os arquivos neste nvim e o nvim comanda o Unity (compilar ao salvar, play/stop, erros, Console).
-- Lado Unity: pacote com.ruilanberg.unity-nvim (Preferences > External Tools > External Script Editor = Neovim)
return {
  {
    "ruilanberg/unity-nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      { "<leader>Up", "<cmd>Unity play<cr>", desc = "Play" },
      { "<leader>Us", "<cmd>Unity stop<cr>", desc = "Stop" },
      { "<leader>UP", "<cmd>Unity pause<cr>", desc = "Pause" },
      { "<leader>Ur", "<cmd>Unity refresh<cr>", desc = "Refresh / compile" },
      { "<leader>Ul", "<cmd>Unity log<cr>", desc = "Console" },
      { "<leader>Ui", "<cmd>Unity status<cr>", desc = "Status" },
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      table.insert(opts.sections.lualine_x, 1, require("unity-nvim.statusline").lualine())
    end,
  },
  {
    "folke/which-key.nvim",
    opts = { spec = { { "<leader>U", group = "unity" } } },
  },
}
