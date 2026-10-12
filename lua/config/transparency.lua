-- Fundo transparente: o nvim deixa de pintar o fundo e a opacidade do Windows Terminal aparece.
-- Vale para qualquer tema (reaplica a cada :colorscheme). Alternar: <leader>uo
local M = {}

M.enabled = true

-- grupos cujo fundo vira transparente (janelas flutuantes continuam opacas para legibilidade)
local groups = {
  "Normal", "NormalNC", "SignColumn", "FoldColumn", "EndOfBuffer", "LineNr", "CursorLineNr",
  "WinSeparator", "VertSplit", "StatusLine", "StatusLineNC", "TabLine", "TabLineFill",
  "NeoTreeNormal", "NeoTreeNormalNC", "NeoTreeEndOfBuffer",
  "SnacksNormal", "SnacksNormalNC", "SnacksPickerList", "SnacksPickerPreview",
  "SnacksDashboardNormal", "BufferLineFill", "MiniIconsNormal",
}

-- cores originais do tema atual (zeradas a cada :colorscheme); só a 1ª captura vale,
-- senão uma 2ª aplicação (ex.: VimEnter) guardaria as cores já transparentes
local saved = {} ---@type table<string, table>

local function apply()
  for _, g in ipairs(groups) do
    local hl = vim.api.nvim_get_hl(0, { name = g, link = false })
    saved[g] = saved[g] or vim.deepcopy(hl)
    if next(hl) or g == "Normal" then
      hl.bg = nil
      hl.ctermbg = nil
      vim.api.nvim_set_hl(0, g, hl)
    end
  end
end

local function restore()
  for g, hl in pairs(saved) do
    vim.api.nvim_set_hl(0, g, hl)
  end
end

---@param on boolean
---@param silent? boolean
function M.set(on, silent)
  if on == M.enabled then
    return
  end
  M.enabled = on
  if on then
    apply()
  else
    restore()
  end
  if not silent then
    vim.notify("Fundo transparente: " .. (on and "ligado" or "desligado"), vim.log.levels.INFO, { title = "UI" })
  end
end

function M.toggle()
  M.set(not M.enabled)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("transparency", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function()
      saved = {} -- tema novo: novas cores originais
      if M.enabled then
        apply()
      end
    end,
  })
  -- garantia: temas carregados por função (ex.: require("tokyonight").load()) não disparam ColorScheme
  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    once = true,
    callback = function()
      if M.enabled then
        apply()
      end
    end,
  })
  vim.keymap.set("n", "<leader>uo", M.toggle, { desc = "Toggle Transparent Background" })
end

return M
