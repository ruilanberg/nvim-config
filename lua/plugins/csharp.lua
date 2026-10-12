-- C# (Unity 6 / .NET) via Roslyn LSP — o mesmo servidor da extensão C# do VS Code
return {
  {
    "mason-org/mason.nvim",
    opts = {
      -- registry extra que publica o pacote "roslyn"
      registries = {
        "github:mason-org/mason-registry",
        "github:Crashdummyy/mason-registry",
      },
      ensure_installed = { "roslyn" },
    },
  },

  {
    "seblyng/roslyn.nvim",
    -- não usar lazy por ft: o plugin/ do roslyn.nvim já habilita o LSP ao carregar, antes do setup()
    -- (subiria um cliente sem o choose_target e outro com ele). O custo no startup é desprezível.
    lazy = false,
    ---@module 'roslyn.config'
    ---@type RoslynNvimConfig
    opts = {
      -- Unity gera .sln e .slnx (front-child): prefere o .sln, que o Roslyn carrega com os .csproj do Unity
      choose_target = function(targets)
        return vim.iter(targets):find(function(t)
          return t:match("%.sln$")
        end) -- nil = deixa o roslyn.nvim escolher
      end,
      -- Projetos Unity têm milhares de arquivos em Library/; o watcher do próprio Roslyn é mais leve no Windows
      filewatching = "roslyn",
    },
    config = function(_, opts)
      vim.lsp.config("roslyn", {
        settings = {
          ["csharp|inlay_hints"] = {
            csharp_enable_inlay_hints_for_implicit_object_creation = true,
            csharp_enable_inlay_hints_for_implicit_variable_types = true,
          },
          ["csharp|code_lens"] = {
            dotnet_enable_references_code_lens = true,
          },
          ["csharp|completion"] = {
            dotnet_show_completion_items_from_unimported_namespaces = true,
          },
          ["csharp|background_analysis"] = {
            dotnet_analyzer_diagnostics_scope = "openFiles",
            dotnet_compiler_diagnostics_scope = "openFiles",
          },
        },
      })
      require("roslyn").setup(opts)
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "c_sharp" } },
  },
  -- Formatação: sem formatter no conform para cs, o LazyVim cai no Roslyn (que respeita o .editorconfig)
}
