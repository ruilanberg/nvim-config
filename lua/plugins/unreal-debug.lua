-- Debug de projetos Unreal no nvim: anexa o codelldb ao UnrealEditor.exe já aberto.
-- Uso: abra o projeto no editor, ponha breakpoints (<leader>db) e rode :UnrealAttach
-- (ou <leader>dc → "Unreal: anexar ao editor"). Dê Play no editor para cair nos breakpoints.
--
-- Detalhe importante: ao ANEXAR, o LLDB no Windows registra no máximo 500 módulos, e o editor carrega
-- ~1300; as DLLs do projeto carregam por último e ficam de fora (breakpoint "Resolved locations: 0").
-- Por isso as DLLs do projeto/plugins são registradas à mão depois do attach (endereço lido do processo).
local UE_FORMATTERS = "Engine/Extras/LLDBDataFormatters/UEDataFormatters_2ByteChars.py" -- TCHAR = 2 bytes no Windows
local NAME = "Unreal: anexar ao editor"

local function project_root()
  return (require("config.unreal").project()) or vim.uv.cwd()
end

local function engine_root(root)
  return require("config.unreal").engine_root(root)
end

--- Editores abertos e, para cada um, as DLLs carregadas que estão dentro do projeto (caminho + base)
---@return { pid: integer, mods: { path: string, base: integer }[] }[]
local function editors(root)
  local ps = ([[
$root = '%s'
@(Get-Process UnrealEditor -ErrorAction SilentlyContinue | ForEach-Object {
  [pscustomobject]@{ pid = $_.Id; mods = @($_.Modules | Where-Object { $_.FileName -like "$root*" } |
    ForEach-Object { [pscustomobject]@{ path = $_.FileName; base = [string][Int64]$_.BaseAddress } }) }
}) | ConvertTo-Json -Depth 4 -Compress
]]):format(root:gsub("/", "\\"))
  local out = vim.system({ "pwsh", "-NoProfile", "-NonInteractive", "-Command", ps }, { text = true }):wait().stdout or ""
  local ok, data = pcall(vim.json.decode, vim.trim(out))
  if not ok or type(data) ~= "table" then
    return {}
  end
  if data.pid then -- um único objeto vira tabela simples
    data = { data }
  end
  for _, e in ipairs(data) do
    if e.mods and e.mods.path then
      e.mods = { e.mods }
    end
    for _, m in ipairs(e.mods or {}) do
      m.base = tonumber(m.base)
    end
  end
  return data
end

--- ImageBase preferido do PE (offset do header em 0x3C; ImageBase em PE+0x30 no PE32+)
local function preferred_base(path)
  local f = io.open(path, "rb")
  if not f then
    return nil
  end
  local head = f:read(4096)
  f:close()
  local function u32(o)
    local a, b, c, d = head:byte(o + 1, o + 4)
    return a + b * 0x100 + c * 0x10000 + d * 0x1000000
  end
  local pe = u32(0x3C)
  return u32(pe + 0x30) + u32(pe + 0x34) * 0x100000000
end

--- Completa a config de attach: escolhe o editor do projeto atual e registra as DLLs do projeto
local function resolve(config)
  local root = project_root()
  local list = editors(root)
  if #list == 0 then
    vim.notify("Nenhum UnrealEditor.exe aberto", vim.log.levels.WARN, { title = "Unreal" })
    return nil
  end
  -- prefere o editor que carregou DLLs deste projeto
  table.sort(list, function(a, b)
    return #(a.mods or {}) > #(b.mods or {})
  end)
  local ed = list[1]
  -- breakpoints desligados enquanto as DLLs são registradas (~10s): uma parada nessa fase não chega ao nvim
  -- e deixaria o editor congelado sem aviso. Religados no fim, a 1ª parada já vem com a sessão pronta.
  local post = { "breakpoint disable" }
  for _, m in ipairs(ed.mods or {}) do
    local pref = preferred_base(m.path)
    if pref and m.path:lower():match("%.dll$") then
      local path = m.path:gsub("\\", "/")
      post[#post + 1] = ('target modules add "%s"'):format(path)
      post[#post + 1] = ("target modules load --file %s --slide 0x%x"):format(vim.fs.basename(path), m.base - pref)
    end
  end
  post[#post + 1] = "breakpoint enable"
  local init = {
    -- o editor carrega centenas de DLLs com .pdb: símbolos sob demanda
    "settings set symbols.load-on-demand true",
    "settings set target.preload-symbols false",
  }
  local fmt = engine_root(root) .. "/" .. UE_FORMATTERS
  if vim.uv.fs_stat(fmt) then
    init[#init + 1] = ('command script import "%s"'):format(fmt)
  end
  vim.notify(("Anexando ao editor (PID %d), %d DLLs do projeto — leva ~1 min"):format(ed.pid, (#post - 2) / 2), vim.log.levels.INFO,
    { title = "Unreal" })
  return vim.tbl_extend("force", config, { pid = ed.pid, initCommands = init, postRunCommands = post })
end

local function attach_config()
  return { type = "codelldb", request = "attach", name = NAME, pid = 0 }
end

-- só Windows (Get-Process do PowerShell, cabeçalho PE das DLLs, UnrealEditor.exe)
if vim.fn.has("win32") == 0 then
  return {}
end

return {
  {
    "mfussenegger/nvim-dap",
    optional = true,
    init = function()
      -- disponível antes do nvim-dap carregar (o require carrega o plugin)
      vim.api.nvim_create_user_command("UnrealAttach", function()
        require("dap").run(attach_config())
      end, { desc = "Anexar o codelldb ao Unreal Editor" })
    end,
    opts = function()
      local dap = require("dap")
      dap.configurations.cpp = dap.configurations.cpp or {}
      table.insert(dap.configurations.cpp, 1, attach_config())
      -- preenche pid/comandos na hora de rodar (vale tanto para :UnrealAttach quanto para <leader>dc)
      dap.listeners.on_config["unreal_attach"] = function(config)
        if config.name ~= NAME then
          return config
        end
        -- o nvim-dap cancela quando algum campo da config vale ABORT
        return resolve(config) or vim.tbl_extend("force", config, { pid = require("dap").ABORT })
      end
    end,
  },
}
