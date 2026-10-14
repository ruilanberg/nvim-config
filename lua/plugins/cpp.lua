-- C/C++ (Unreal 5.8, CMake) — no Windows usa o clangd do LLVM instalado via winget, não o do Mason
return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local clangd = opts.servers.clangd or {}
      -- Windows: clangd do LLVM (winget); Mac: o da Apple (/usr/bin/clangd), o único que entende os
      -- módulos da libc++ do Xcode que o UBT usa (o do Mason dá "module 'std_core' is needed"); Linux: o do Mason
      local mac = vim.fn.has("mac") == 1
      clangd.mason = vim.fn.has("win32") == 0 and not mac
      clangd.cmd = {
        mac and "/usr/bin/clangd" or "clangd",
        "--background-index",
        "--clang-tidy",
        "--header-insertion=never", -- Unreal tem convenções próprias de include
        "--completion-style=detailed",
        "--function-arg-placeholders",
        "--fallback-style=llvm",
        "-j=6",
        "--pch-storage=disk", -- Unreal estoura RAM com PCH em memória
        -- permite ao clangd consultar o MSVC / clang-cl para achar headers do sistema
        "--query-driver=**/cl.exe,**/clang-cl.exe,**/clang++.exe,**/clang.exe",
      }
      opts.servers.clangd = clangd
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "cpp", "c", "hlsl", "glsl" } },
  },

  -- CMake: build / run / debug (codelldb) para qualquer projeto CMake.
  -- Usa o CMakePresets.json do projeto quando existir; senão Ninja + MSVC.
  {
    "Civitasv/cmake-tools.nvim",
    opts = {
      cmake_regenerate_on_save = false,
      -- compile_commands.json do clangd é gerado pelo cmake-compdb.ps1 (presets VS não exportam)
      cmake_compile_commands_options = { action = "none" },
      cmake_generate_options = { "-DCMAKE_EXPORT_COMPILE_COMMANDS=1" },
      cmake_kits_path = vim.fn.stdpath("config") .. "/cmake-kits.json",
      cmake_dap_configuration = {
        name = "cpp",
        type = "codelldb",
        request = "launch",
        stopOnEntry = false,
        runInTerminal = false,
        console = "integratedTerminal",
      },
      cmake_executor = { name = "quickfix", opts = { show = "only_on_error" } },
      cmake_runner = { name = "terminal" },
    },
    config = function(_, opts)
      -- Sem o ambiente do MSVC (cl.exe, Windows SDK) os kits Ninja não configuram.
      -- Carrega o vcvars64 uma vez, só quando um projeto CMake é aberto.
      if vim.fn.has("win32") == 1 and vim.fn.executable("cl") == 0 then
        local vswhere = vim.fs.joinpath(vim.env["ProgramFiles(x86)"], "Microsoft Visual Studio/Installer/vswhere.exe")
        local vs = vim.trim(vim.fn.system({
          vswhere, "-latest", "-products", "*",
          "-requires", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
          "-property", "installationPath",
        }))
        local vcvars = vs ~= "" and vim.fs.joinpath(vs, "VC/Auxiliary/Build/vcvars64.bat")
        if vcvars and vim.uv.fs_stat(vcvars) then
          -- .bat temporário: evita o quoting do `cmd /c` (o 'shell' do nvim é pwsh)
          local bat = vim.fn.tempname() .. ".bat"
          vim.fn.writefile({ "@call \"" .. vcvars:gsub("/", "\\") .. "\" >nul", "@set" }, bat)
          local out = vim.system({ bat }, { text = true }):wait().stdout or ""
          os.remove(bat)
          for line in out:gmatch("[^\r\n]+") do
            local k, v = line:match("^([^=]+)=(.*)$")
            if k then
              vim.env[k] = v
            end
          end
        end
      end
      require("cmake-tools").setup(opts)
    end,
    keys = {
      { "<leader>mg", "<cmd>CMakeGenerate<cr>", desc = "Generate (configure)" },
      { "<leader>mb", "<cmd>CMakeBuild<cr>", desc = "Build" },
      { "<leader>mr", "<cmd>CMakeRun<cr>", desc = "Run" },
      { "<leader>md", "<cmd>CMakeDebug<cr>", desc = "Debug" },
      { "<leader>mt", "<cmd>CMakeSelectLaunchTarget<cr>", desc = "Select launch target" },
      { "<leader>mT", "<cmd>CMakeSelectBuildTarget<cr>", desc = "Select build target" },
      { "<leader>mp", "<cmd>CMakeSelectConfigurePreset<cr>", desc = "Select configure preset" },
      { "<leader>mP", "<cmd>CMakeSelectBuildPreset<cr>", desc = "Select build preset (Debug/Release)" },
      { "<leader>mk", "<cmd>CMakeSelectKit<cr>", desc = "Select kit" },
      { "<leader>mv", "<cmd>CMakeSelectBuildType<cr>", desc = "Select build type" },
      { "<leader>mc", "<cmd>CMakeClean<cr>", desc = "Clean" },
      { "<leader>ms", "<cmd>CMakeStopExecutor<cr>", desc = "Stop" },
    },
  },
  -- codelldb no Windows: o primeiro start (liblldb.dll ~100MB + antivírus) passa dos ~3.5s
  -- de tentativas padrão do nvim-dap, e a conexão falha com ECONNREFUSED.
  {
    "jay-babu/mason-nvim-dap.nvim",
    optional = true,
    opts = {
      handlers = {
        codelldb = function(config)
          config.adapters = vim.tbl_deep_extend("force", config.adapters, {
            host = "127.0.0.1",
            options = { max_retries = 80 }, -- 80 x 250ms = 20s
          })
          require("mason-nvim-dap").default_setup(config)
        end,
      },
    },
  },
  {
    "folke/which-key.nvim",
    opts = { spec = { { "<leader>m", group = "cmake" } } },
  },
}
