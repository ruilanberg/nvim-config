-- Barra de status: LSPs do buffer atual, com spinner enquanto algo ainda está carregando:
--   * abertura adiada (fastopen) pendente
--   * nenhum LSP anexado ainda, mas há servidor habilitado para o filetype (até 5s; alguns, como o
--     biome, só anexam se o projeto tiver config e nunca vão aparecer)
--   * servidor não inicializado ou com $/progress em andamento (indexando, carregando projeto…)
local spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local PENDING_WINDOW = 5 -- segundos esperando o 1º LSP anexar
local busy = {} ---@type table<integer, table<string, true>> client_id -> tokens de progresso abertos
local timer ---@type uv.uv_timer_t?

local function has_enabled_server(ft)
  local ok, enabled = pcall(function()
    return vim.lsp._enabled_configs
  end)
  for name in pairs(ok and enabled or {}) do
    local cfg = vim.lsp.config[name]
    if cfg and type(cfg.filetypes) == "table" and vim.tbl_contains(cfg.filetypes, ft) then
      return true
    end
  end
  return false
end

local function loading(buf)
  if vim.bo[buf].buftype ~= "" or vim.bo[buf].filetype == "" then
    return false
  end
  if not vim.b[buf].fastopen_ready then
    return true
  end
  local clients = vim.lsp.get_clients({ bufnr = buf })
  if #clients == 0 then
    local t0 = vim.b[buf].lsp_status_t0
    return t0 ~= nil and (vim.uv.hrtime() - t0) / 1e9 < PENDING_WINDOW and has_enabled_server(vim.bo[buf].filetype)
  end
  for _, c in ipairs(clients) do
    if not c.initialized or next(busy[c.id] or {}) then
      return true
    end
  end
  return false
end

local function refresh()
  require("lualine").refresh({ place = { "statusline" } })
end

-- anima o spinner só enquanto há algo carregando; parado, não custa nada
local function animate()
  if timer then
    return
  end
  local t = assert(vim.uv.new_timer())
  timer = t
  t:start(0, 100, vim.schedule_wrap(function()
    if timer ~= t then
      return -- callback atrasado de um timer já encerrado
    end
    refresh()
    if not loading(vim.api.nvim_get_current_buf()) then
      timer = nil
      t:stop()
      t:close()
      refresh()
    end
  end))
end

local group = vim.api.nvim_create_augroup("lsp_status", { clear = true })
vim.api.nvim_create_autocmd("LspProgress", {
  group = group,
  callback = function(ev)
    local id, value = ev.data.client_id, ev.data.params.value
    local token = tostring(ev.data.params.token)
    busy[id] = busy[id] or {}
    if value.kind == "end" then
      busy[id][token] = nil
    else
      busy[id][token] = true
      animate()
    end
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  group = group,
  callback = function(ev)
    vim.b[ev.buf].lsp_status_t0 = vim.uv.hrtime()
    animate()
  end,
})
vim.api.nvim_create_autocmd({ "LspAttach", "LspDetach", "BufEnter" }, {
  group = group,
  callback = function(ev)
    if ev.event == "LspDetach" then
      busy[ev.data.client_id] = nil
    end
    if loading(ev.buf) then
      animate()
    end
  end,
})

local component = {
  function()
    local buf = vim.api.nvim_get_current_buf()
    local names = vim.tbl_map(function(c)
      return c.name
    end, vim.lsp.get_clients({ bufnr = buf }))
    if loading(buf) then
      local frame = spinner[math.floor(vim.uv.hrtime() / 1e8) % #spinner + 1]
      return frame .. " " .. (#names > 0 and table.concat(names, " ") or "LSP")
    end
    return #names > 0 and (" " .. table.concat(names, " ")) or ""
  end,
  color = function()
    return { fg = Snacks.util.color(loading(vim.api.nvim_get_current_buf()) and "DiagnosticWarn" or "DiagnosticOk") }
  end,
}

return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      table.insert(opts.sections.lualine_x, 1, component)
    end,
  },
}
