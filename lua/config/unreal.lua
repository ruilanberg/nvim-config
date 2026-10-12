-- Projetos Unreal: localizar projeto/engine e compilar pelo UnrealBuildTool sem sair do nvim.
-- :UnrealBuild [Development|DebugGame] (padrão: a última usada) — erros do compilador vão para a quickfix.
-- :UnrealBuildStop interrompe. Com o editor aberto e Live Coding ligado o UBT recusa: use Ctrl+Alt+F11 no editor.
local M = {}

local CONFIGS = { "Development", "DebugGame" }
local last_config = "Development"
local job ---@type vim.SystemObj?

-- MSVC (com e sem coluna), UHT ("Error:"/"Warning:") e clang (Linux/Mac); %t pega o e/E/w/W
local EFM = table.concat({
  "%f(%l\\,%c): fatal %trror%*[: ]%m",
  "%f(%l\\,%c): %trror%*[: ]%m",
  "%f(%l\\,%c): %tarning%*[: ]%m",
  "%f(%l): fatal %trror%*[: ]%m",
  "%f(%l): %trror%*[: ]%m",
  "%f(%l): %tarning%*[: ]%m",
  "%f:%l:%c: fatal %trror: %m",
  "%f:%l:%c: %trror: %m",
  "%f:%l:%c: %tarning: %m",
}, ",")

--- Plataforma do UBT para a máquina atual
---@return "Win64"|"Mac"|"Linux"
function M.platform()
  if vim.fn.has("win32") == 1 then
    return "Win64"
  end
  return vim.fn.has("mac") == 1 and "Mac" or "Linux"
end

---@param path? string arquivo ou pasta; padrão = buffer atual / cwd
---@return string? root, string? uproject
function M.project(path)
  local root = vim.fs.root(path or 0, function(name)
    return name:match("%.uproject$") ~= nil
  end) or vim.fs.root(vim.uv.cwd(), function(name)
    return name:match("%.uproject$") ~= nil
  end)
  if not root then
    return nil
  end
  return root, vim.fn.glob(root .. "/*.uproject", false, true)[1]
end

local function is_engine(dir)
  return dir and vim.uv.fs_stat(dir .. "/Engine/Build/Build.version") ~= nil
end

local function reg_value(key, value)
  local out = vim.system({ "reg", "query", key, "/v", value }, { text = true }):wait().stdout or ""
  return out:match(vim.pesc(value) .. "%s+REG_SZ%s+([^\r\n]+)")
end

--- Engines registradas no Install.ini do Linux/Mac ([Installations] associação=pasta)
local function install_ini(assoc)
  local ini = M.platform() == "Mac" and "~/Library/Application Support/Epic/UnrealEngine/Install.ini"
    or "~/.config/Epic/UnrealEngine/Install.ini"
  local ok, lines = pcall(vim.fn.readfile, vim.fs.normalize(ini))
  for _, line in ipairs(ok and lines or {}) do
    local k, v = line:match("^%s*([^=]+)=(.+)$")
    if k and vim.trim(k) == assoc then
      return vim.trim(v)
    end
  end
end

--- Raiz da engine a partir do .uproject. Ordem: $UE_ROOT, projeto dentro da árvore da engine
--- (EngineAssociation vazia), registro do Launcher / builds de código-fonte (Windows) ou Install.ini
--- (Linux/Mac), pasta padrão do Launcher.
---@return string
function M.engine_root(root)
  if is_engine(vim.env.UE_ROOT) then
    return vim.fs.normalize(vim.env.UE_ROOT)
  end
  local uproject = vim.fn.glob(root .. "/*.uproject", false, true)[1]
  local assoc = "5.8"
  if uproject then
    local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(uproject), "\n"))
    assoc = ok and type(data.EngineAssociation) == "string" and data.EngineAssociation or assoc
  end
  if assoc == "" then
    for dir in vim.fs.parents(root) do
      if is_engine(dir) then
        return dir
      end
    end
  end

  local dir
  if M.platform() == "Win64" then
    dir = reg_value("HKLM\\SOFTWARE\\EpicGames\\Unreal Engine\\" .. assoc, "InstalledDirectory")
      or reg_value("HKCU\\Software\\Epic Games\\Unreal Engine\\Builds", assoc)
      or ("C:/Program Files/Epic Games/UE_" .. assoc)
  else
    dir = install_ini(assoc) or (M.platform() == "Mac" and "/Users/Shared/Epic Games/UE_" .. assoc)
      or vim.fs.normalize("~/UnrealEngine")
  end
  return (dir:gsub("\\", "/"))
end

--- Comando do UnrealBuildTool para a plataforma atual (nil se não existir na engine)
---@param engine string
---@param args string[]
---@return string[]?
function M.ubt_cmd(engine, args)
  local platform = M.platform()
  local candidates = platform == "Win64"
      -- builds do Launcher não trazem RunUBT.bat; o UnrealBuildTool.exe existe em ambas
      and { engine .. "/Engine/Binaries/DotNET/UnrealBuildTool/UnrealBuildTool.exe" }
    or {
      engine .. "/Engine/Build/BatchFiles/" .. platform .. "/Build.sh",
      engine .. "/Engine/Build/BatchFiles/RunUBT.sh",
    }
  for _, exe in ipairs(candidates) do
    if vim.uv.fs_stat(exe) then
      local cmd = exe:match("%.sh$") and { "bash", exe } or { exe }
      return vim.list_extend(cmd, args)
    end
  end
end

--- Linhas de saída do UBT → itens da quickfix (só os que apontam para arquivo/linha, sem repetidos)
local function qf_items(lines)
  local items, seen = {}, {}
  for _, it in ipairs(vim.fn.getqflist({ lines = lines, efm = EFM }).items) do
    local key = ("%d:%d:%s"):format(it.bufnr, it.lnum, it.text)
    if it.valid == 1 and not seen[key] then
      seen[key] = true
      items[#items + 1] = it
    end
  end
  return items
end

---@param config? string
function M.build(config)
  if job then
    vim.notify("Já existe um build em andamento (:UnrealBuildStop)", vim.log.levels.WARN, { title = "Unreal" })
    return
  end
  local root, uproject = M.project()
  if not root or not uproject then
    vim.notify("Nenhum .uproject acima do arquivo/pasta atual", vim.log.levels.WARN, { title = "Unreal" })
    return
  end
  config = config ~= "" and config or last_config
  last_config = config
  local platform = M.platform()
  local name = vim.fn.fnamemodify(uproject, ":t:r")
  local target = name .. "Editor"
  local args = { target, platform, config, "-Project=" .. uproject, "-WaitMutex" }
  if platform == "Win64" then
    args[#args + 1] = "-FromMsBuild" -- erros no formato do MSVC, um por linha
  end
  local engine = M.engine_root(root)
  local cmd = M.ubt_cmd(engine, args)
  if not cmd then
    vim.notify("UnrealBuildTool não encontrado na engine:\n" .. engine .. "\n(defina $UE_ROOT)", vim.log.levels.ERROR,
      { title = "Unreal" })
    return
  end

  vim.cmd("silent! wall")
  local t0 = vim.uv.hrtime()
  vim.notify(("Compilando %s %s %s…"):format(target, platform, config), vim.log.levels.INFO, { title = "Unreal" })

  job = vim.system(
    cmd,
    { text = true, cwd = root },
    vim.schedule_wrap(function(res)
      job = nil
      local out = (res.stdout or "") .. "\n" .. (res.stderr or "")
      local lines = vim.split(out:gsub("\r", ""), "\n", { trimempty = true })
      local items = qf_items(lines)
      vim.fn.setqflist({}, " ", { title = ("UnrealBuild %s %s"):format(target, config), items = items })
      local secs = (vim.uv.hrtime() - t0) / 1e9

      if res.signal ~= 0 then
        vim.notify("Build interrompido", vim.log.levels.WARN, { title = "Unreal" })
      elseif out:find("Unable to build while Live Coding is active", 1, true) then
        vim.notify("O editor está aberto com Live Coding: compile por lá com Ctrl+Alt+F11", vim.log.levels.WARN,
          { title = "Unreal" })
      elseif res.code == 0 then
        local warns = #items > 0 and (" (%d avisos na quickfix)"):format(#items) or ""
        vim.notify(("Build OK em %.0fs%s"):format(secs, warns), vim.log.levels.INFO, { title = "Unreal" })
      else
        local errors = #vim.tbl_filter(function(it)
          return it.type:lower() == "e"
        end, items)
        if #items > 0 then
          vim.notify(("Build falhou: %d erro(s) em %.0fs"):format(errors, secs), vim.log.levels.ERROR, { title = "Unreal" })
          vim.cmd("botright copen")
          vim.cmd("wincmd p")
        else
          -- falha sem arquivo/linha (ex.: erro do UBT/UHT): mostra o fim da saída
          local tail = table.concat(vim.list_slice(lines, math.max(1, #lines - 15)), "\n")
          vim.notify(("Build falhou (exit %d)\n%s"):format(res.code, tail), vim.log.levels.ERROR, { title = "Unreal" })
        end
      end
    end)
  )
end

function M.stop()
  if job then
    job:kill("sigterm")
  end
end

function M.setup()
  vim.api.nvim_create_user_command("UnrealBuild", function(a)
    M.build(a.args)
  end, {
    nargs = "?",
    complete = function()
      return CONFIGS
    end,
    desc = "Compilar o projeto Unreal (UnrealBuildTool)",
  })
  vim.api.nvim_create_user_command("UnrealBuildStop", M.stop, { desc = "Interromper o build do Unreal" })
  vim.keymap.set("n", "<leader>cb", "<cmd>UnrealBuild<cr>", { desc = "Unreal Build" })
end

return M
