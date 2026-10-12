-- Linguagens sem extra do LazyVim: Protobuf, PowerShell, Bash, HLSL, XML (UXML)
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        buf_ls = {}, -- .proto (service-internal-api)
        powershell_es = {}, -- .ps1 (scripts de Unreal/projetos)
        bashls = {},
        lemminx = {}, -- .uxml, .xml, .csproj
        slangd = {}, -- HLSL: .hlsl/.usf/.ush/.cginc (o .shader do Unity é ShaderLab, fica só com highlight)
      },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "tree-sitter-cli", -- exigido pelo nvim-treesitter atual
        "buf", -- buf_ls + buf format
        "shfmt",
        "shellcheck",
      },
    },
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        proto = { "buf" },
        sh = { "shfmt" },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "proto",
        "powershell",
        "bash",
        "xml",
        "scss",
      },
    },
  },
}
