-- Abertura rápida: o arquivo aparece na hora e o que é pesado liga logo depois do primeiro desenho.
-- O treesitter compila as queries (highlight/indent/folds) de forma síncrona na 1ª vez de cada linguagem
-- (~100-250ms). Aqui o handler de FileType do LazyVim é adiado para depois do redraw; até lá vale o
-- highlight clássico do Vim, que é instantâneo. O LSP já sobe em segundo plano (vim.lsp.enable).
local M = {}

--- Buffer liberado para recursos que usam treesitter (ex.: snacks.scope). Dispara CursorMoved
--- para quem escuta (scope) recalcular já com o parser pronto.
function M.mark_ready(buf)
  if vim.b[buf].fastopen_ready then
    return
  end
  vim.b[buf].fastopen_ready = true
  vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf, modeline = false })
end

function M.is_ready(buf)
  return vim.b[buf].fastopen_ready == true
end

--- Substitui os autocmds FileType de um augroup por versões adiadas (mesmo callback, mesmo evento)
local function defer_group(group_name)
  local ok, aus = pcall(vim.api.nvim_get_autocmds, { group = group_name, event = "FileType" })
  if not ok then
    return
  end
  for _, au in ipairs(aus) do
    local cb = au.callback
    -- idempotente: não adia de novo o que já foi adiado
    if type(cb) == "function" and not (au.desc or ""):find("(adiado)", 1, true) then
      vim.api.nvim_del_autocmd(au.id)
      vim.api.nvim_create_autocmd("FileType", {
        group = group_name,
        pattern = au.pattern,
        desc = (au.desc or "") .. " (adiado)",
        callback = function(ev)
          vim.defer_fn(function()
            if vim.api.nvim_buf_is_valid(ev.buf) and vim.bo[ev.buf].filetype == ev.match then
              -- roda no contexto do buffer: o handler ajusta opções locais (indentexpr/foldexpr)
              vim.api.nvim_buf_call(ev.buf, function()
                cb(ev)
              end)
              M.mark_ready(ev.buf)
            end
          end, 0)
        end,
      })
    end
  end
end

M.defer_group = defer_group

--- Para usar como `config` de um plugin: roda o config herdado (ex.: o do LazyVim) e depois
--- adia os autocmds FileType dos grupos indicados. Tudo síncrono, então vale já para o 1º arquivo
--- (o lazy.nvim redispara o FileType logo após o config).
---@param groups string[]
function M.wrap_config(groups)
  local wrapped
  wrapped = function(plugin, opts)
    -- sobe a cadeia de specs (lazy.nvim encadeia fragmentos via __index): passa por este wrapper
    -- e chama o próximo config abaixo dele (o original, ex.: do LazyVim)
    local mt = getmetatable(plugin)
    local node = mt and mt.__index
    local passed = false
    while type(node) == "table" do
      local cfg = rawget(node, "config")
      if cfg == wrapped then
        passed = true
      elseif passed and type(cfg) == "function" then
        cfg(plugin, opts)
        break
      end
      local nmt = getmetatable(node)
      node = nmt and nmt.__index
    end
    for _, g in ipairs(groups) do
      defer_group(g)
    end
  end
  return wrapped
end

return M
