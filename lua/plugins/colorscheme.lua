-- Tema: fluoromachine (synthwave / Tron / Hackers). Transparência em lua/config/transparency.lua
return {
  -- tema padrão (string -> passa por :colorscheme e dispara o evento ColorScheme)
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "fluoromachine" },
  },
  -- temas que vêm com o LazyVim: não usados
  { "folke/tokyonight.nvim", enabled = false },
  { "catppuccin/nvim", name = "catppuccin", enabled = false },
  {
    "maxmx03/fluoromachine.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("fluoromachine").setup({ glow = false, theme = "fluoromachine" })
    end,
  },
}
