-- Abertura rápida (ver lua/config/fastopen.lua): o que depende do treesitter liga logo depois
-- do primeiro desenho, em vez de travar a abertura do arquivo.
local fastopen = require("config.fastopen")

return {
  {
    "nvim-treesitter/nvim-treesitter",
    config = fastopen.wrap_config({ "lazyvim_treesitter" }),
  },
  {
    -- início dos LSPs (carregar módulos, validar config, spawn do processo) depois do 1º desenho.
    -- O autocmd FileType do vim.lsp.enable fica no grupo "nvim.lsp.enable" e é criado uma única vez.
    "neovim/nvim-lspconfig",
    config = fastopen.wrap_config({ "nvim.lsp.enable" }),
  },
  {
    -- sinais do git: carrega logo depois da tela aparecer (anexa aos buffers já abertos)
    "lewis6991/gitsigns.nvim",
    -- forma de função: substitui a lista do LazyVim (LazyFile) em vez de mesclar
    event = function()
      return { "VeryLazy" }
    end,
  },
  {
    -- snacks.scope (bloco atual) pedia o parser do treesitter de forma síncrona na abertura
    "folke/snacks.nvim",
    opts = {
      scope = {
        filter = function(buf)
          return vim.bo[buf].buftype == ""
            and vim.b[buf].snacks_scope ~= false
            and vim.g.snacks_scope ~= false
            and fastopen.is_ready(buf)
        end,
      },
    },
  },
}
