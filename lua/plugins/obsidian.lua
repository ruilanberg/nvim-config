-- Vaults do Obsidian (docs do Maneuver e operação do IGP)
local projects = vim.fn.expand("~/Documents/Projects")

return {
  {
    "obsidian-nvim/obsidian.nvim",
    version = "*",
    ft = "markdown",
    cmd = "Obsidian",
    ---@module 'obsidian'
    ---@type obsidian.config
    opts = {
      legacy_commands = false,
      workspaces = {
        { name = "maneuver", path = projects .. "/Maneuver/Docs/Vault" },
        { name = "igp", path = projects .. "/Saas/IGP/Operacao" },
      },
      ui = { enable = false }, -- render-markdown.nvim (extra lang.markdown) já cuida da renderização
      picker = { name = "snacks.pick" },
    },
  },
}
