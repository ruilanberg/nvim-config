-- Mantém o compile_commands.json do clangd atualizado em projetos Unreal e CMake.
-- Detecta quando o banco está desatualizado e roda ue-compdb.ps1 / cmake-compdb.ps1 em segundo plano.
local M = {}

local bin = vim.fs.normalize("~/.local/bin")
local SKIP = { Intermediate = true, Binaries = true, Saved = true, DerivedDataCache = true, [".git"] = true,
  [".cache"] = true, [".vs"] = true, build = true, ["build-clangd"] = true, out = true, _deps = true, node_modules = true }

local running = {} ---@type table<string, boolean>
local last_check = {} ---@type table<string, integer>

local function mtime(path)
  local st = vim.uv.fs_stat(path)
  return st and st.mtime.sec or nil
end

local function norm(p)
  return vim.fs.normalize(p):lower()
end

--- Arquivos sob `dir` (recursivo, pulando pastas geradas) cujo nome casa com `pred`
local function scan(dir, pred)
  local out = {}
  if not vim.uv.fs_stat(dir) then
    return out
  end
  for name, type in vim.fs.dir(dir, {
    depth = 20,
    skip = function(d)
      return not SKIP[vim.fs.basename(d)]
    end,
  }) do
    if type == "file" and pred(vim.fs.basename(name)) then
      out[#out + 1] = vim.fs.joinpath(dir, name)
    end
  end
  return out
end

local function newer_than(files, ref)
  for _, f in ipairs(files) do
    local m = mtime(f)
    if m and m > ref then
      return vim.fs.basename(f)
    end
  end
end

--- Detecta o tipo de projeto a partir de um caminho
---@return { kind: "unreal"|"cmake", root: string }?
local function detect(path)
  local ue = vim.fs.root(path, function(name)
    return name:match("%.uproject$") ~= nil
  end)
  if ue then
    return { kind = "unreal", root = ue }
  end
  -- CMake: o CMakeLists.txt mais alto até a raiz git/presets
  local top = vim.fs.root(path, { "CMakePresets.json", ".git" })
  if top and vim.uv.fs_stat(vim.fs.joinpath(top, "CMakeLists.txt")) then
    return { kind = "cmake", root = top }
  end
end

--- Retorna o motivo se o banco precisa ser regenerado, ou nil
local function stale_reason(proj)
  local db = vim.fs.joinpath(proj.root, "compile_commands.json")
  local db_m = mtime(db)
  if not db_m then
    return "compile_commands.json não existe"
  end

  if proj.kind == "cmake" then
    local cfg = scan(proj.root, function(n)
      return n == "CMakeLists.txt" or n:match("%.cmake$") or n == "CMakePresets.json"
    end)
    local f = newer_than(cfg, db_m)
    return f and (f .. " mudou") or nil
  end

  -- Unreal: arquivos de build/configuração mais novos que o banco
  local cfg = vim.list_extend(
    vim.fn.glob(proj.root .. "/*.uproject", false, true),
    vim.list_extend(
      scan(proj.root .. "/Source", function(n)
        return n:match("%.Build%.cs$") or n:match("%.Target%.cs$")
      end),
      scan(proj.root .. "/Plugins", function(n)
        return n:match("%.uplugin$") or n:match("%.Build%.cs$")
      end)
    )
  )
  local f = newer_than(cfg, db_m)
  if f then
    return f .. " mudou"
  end

  -- .cpp adicionados ou removidos
  local ok, entries = pcall(vim.json.decode, table.concat(vim.fn.readfile(db), "\n"))
  if not ok then
    return "compile_commands.json inválido"
  end
  local known = {}
  for _, e in ipairs(entries) do
    known[norm(e.file)] = true
  end
  local is_src = function(n)
    return n:match("%.cpp$") or n:match("%.cc$") or n:match("%.c$")
  end
  local sources = vim.list_extend(scan(proj.root .. "/Source", is_src), scan(proj.root .. "/Plugins", is_src))
  local present = {}
  for _, s in ipairs(sources) do
    local k = norm(s)
    present[k] = true
    if not known[k] then
      return vim.fs.basename(s) .. " é novo"
    end
  end
  local root_l = norm(proj.root) .. "/"
  for k in pairs(known) do
    local rel = k:sub(1, #root_l) == root_l and k:sub(#root_l + 1)
    if rel and (rel:find("^source/") or rel:find("^plugins/")) and not rel:find("/intermediate/", 1, true)
      and not present[k] then
      return vim.fs.basename(k) .. " foi removido"
    end
  end
end

local function restart_clangd(root)
  for _, c in ipairs(vim.lsp.get_clients({ name = "clangd" })) do
    if c.root_dir and norm(c.root_dir) == norm(root) then
      vim.cmd("lsp restart clangd")
      return
    end
  end
end

--- Roda os comandos em sequência; para no primeiro que falhar. `cb(res)` recebe o último resultado.
---@param cmds (string[]|fun(): vim.SystemCompleted)[] argv ou função síncrona (ex.: copiar arquivo)
local function chain(cmds, cb, i)
  i = i or 1
  local step = cmds[i]
  local function next_step(res)
    if res.code ~= 0 or i == #cmds then
      cb(res)
    else
      chain(cmds, cb, i + 1)
    end
  end
  if type(step) == "function" then
    next_step(step())
  else
    vim.system(step, { text = true }, vim.schedule_wrap(next_step))
  end
end

--- Copia `from` para `to`; erro no formato do vim.system
local function copy(from, to)
  return function()
    local ok, err = vim.uv.fs_copyfile(from, to)
    return { code = ok and 0 or 1, stdout = "", stderr = ok and "" or (err or ("não achei " .. from)) }
  end
end

--- Comandos que geram o banco. Windows: scripts do ~/.local/bin (carregam o ambiente do MSVC).
--- Linux/Mac: UBT (Build.sh -mode=GenerateClangDatabase) ou cmake direto.
---@return (string[]|function)[]?, string? erro
local function commands(proj)
  local db = vim.fs.joinpath(proj.root, "compile_commands.json")
  if vim.fn.has("win32") == 1 then
    local script = proj.kind == "unreal" and "ue-compdb.ps1" or "cmake-compdb.ps1"
    local arg = proj.kind == "unreal" and "-Project" or "-Source"
    return { { "pwsh", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", vim.fs.joinpath(bin, script), arg,
      proj.root } }
  end

  if proj.kind == "cmake" then
    local build = vim.fs.joinpath(proj.root, "build-clangd")
    return {
      { "cmake", "-S", proj.root, "-B", build, "-DCMAKE_BUILD_TYPE=Debug", "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON" },
      copy(vim.fs.joinpath(build, "compile_commands.json"), db),
    }
  end

  local unreal = require("config.unreal")
  local uproject = vim.fn.glob(proj.root .. "/*.uproject", false, true)[1]
  local engine = unreal.engine_root(proj.root)
  local name = vim.fn.fnamemodify(uproject, ":t:r")
  local ubt = unreal.ubt_cmd(engine, { "-mode=GenerateClangDatabase", "-project=" .. uproject, name .. "Editor",
    unreal.platform(), "Development", "-OutputDir=" .. proj.root })
  if not ubt then
    return nil, "UnrealBuildTool não encontrado em " .. engine .. " (defina $UE_ROOT)"
  end
  return {
    ubt,
    function()
      -- versões antigas do UBT ignoram -OutputDir e gravam na raiz da engine
      local engine_db = vim.fs.joinpath(engine, "compile_commands.json")
      if not vim.uv.fs_stat(db) and vim.uv.fs_stat(engine_db) then
        local ok, err = vim.uv.fs_rename(engine_db, db)
        return { code = ok and 0 or 1, stdout = "", stderr = err or "" }
      end
      return { code = 0, stdout = "", stderr = "" }
    end,
  }
end

---@param proj { kind: "unreal"|"cmake", root: string }
---@param reason string
function M.regenerate(proj, reason)
  if running[proj.root] then
    return
  end
  local name = vim.fs.basename(proj.root)
  local cmds, err = commands(proj)
  if not cmds then
    vim.notify(("%s: %s"):format(name, err), vim.log.levels.WARN, { title = "clangd" })
    return
  end
  running[proj.root] = true
  vim.notify(("%s: %s\nregenerando compile_commands.json…"):format(name, reason), vim.log.levels.INFO, { title = "clangd" })

  chain(cmds, function(res)
    running[proj.root] = nil
    last_check[proj.root] = os.time()
    if res.code == 0 then
      vim.notify(name .. ": compile_commands.json atualizado", vim.log.levels.INFO, { title = "clangd" })
      restart_clangd(proj.root)
    else
      local out = vim.trim((res.stderr ~= "" and res.stderr or res.stdout) or "")
      vim.notify(("%s: falha ao gerar (exit %d)\n%s"):format(name, res.code, out:sub(-600)), vim.log.levels.WARN,
        { title = "clangd" })
    end
  end)
end

---@param path string? arquivo ou pasta; padrão = cwd
---@param force boolean?
function M.check(path, force)
  local proj = detect(path or vim.uv.cwd())
  if not proj or running[proj.root] then
    return
  end
  -- no máximo uma verificação a cada 5s por projeto (salvar vários arquivos seguidos)
  local now = os.time()
  if not force and last_check[proj.root] and now - last_check[proj.root] < 5 then
    return
  end
  last_check[proj.root] = now
  local reason = force and "regeneração manual" or stale_reason(proj)
  if reason then
    M.regenerate(proj, reason)
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("compdb_auto", { clear = true })

  -- ao abrir o nvim (o setup roda no VeryLazy, depois do FileType do arquivo passado na linha de comando)
  vim.schedule(function()
    local name = vim.api.nvim_buf_get_name(0)
    M.check(name ~= "" and name or nil)
  end)
  -- ao trocar de pasta
  vim.api.nvim_create_autocmd("DirChanged", {
    group = group,
    callback = function()
      M.check()
    end,
  })
  -- ao abrir um arquivo C/C++ de outro projeto
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = { "c", "cpp" },
    callback = function(ev)
      M.check(vim.api.nvim_buf_get_name(ev.buf))
    end,
  })
  -- ao salvar algo que muda a estrutura do projeto
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = { "*.cpp", "*.cc", "*.c", "*.Build.cs", "*.Target.cs", "*.uplugin", "*.uproject", "CMakeLists.txt", "*.cmake", "CMakePresets.json" },
    callback = function(ev)
      M.check(ev.file)
    end,
  })

  vim.api.nvim_create_user_command("CompdbRefresh", function()
    M.check(vim.api.nvim_buf_get_name(0) ~= "" and vim.api.nvim_buf_get_name(0) or nil, true)
  end, { desc = "Regenerar compile_commands.json (Unreal/CMake)" })
end

return M
