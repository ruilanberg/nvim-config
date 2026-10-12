-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

local is_win = vim.fn.has("win32") == 1

if is_win then
  -- PowerShell 7 como shell de :terminal, :! e formatters.
  -- Mesmas opções do LazyVim.terminal.setup("pwsh"), mas sem o executable("pwsh"):
  -- cada busca no PATH custa ~17ms no Windows, em toda abertura.
  vim.o.shell = "pwsh"
  vim.o.shellcmdflag =
    "-NoProfile -NoLogo -NonInteractive -ExecutionPolicy RemoteSigned -Command [Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new();$PSDefaultParameterValues['Out-File:Encoding']='utf8';$PSStyle.OutputRendering='plaintext';Remove-Alias -Force -ErrorAction SilentlyContinue tee;"
  vim.o.shellredir = '2>&1 | %%{ "$_" } | Out-File %s; exit $LastExitCode'
  vim.o.shellpipe = '2>&1 | %%{ "$_" } | tee %s; exit $LastExitCode'
  vim.o.shellquote = ""
  vim.o.shellxquote = ""

  -- O LazyVim só procura o cl.exe em "Program Files (x86)"; o VS 2022 fica em "Program Files".
  -- Usa o clang do LLVM para compilar os parsers do treesitter (checagem direta do arquivo, sem varrer o PATH).
  if not vim.env.CC and vim.uv.fs_stat("C:/Program Files/LLVM/bin/clang.exe") then
    vim.env.CC = "clang"
  end
end

-- Projetos mistos (Unity gera CRLF, repos web usam LF): detecta os dois, cria novos como LF
vim.opt.fileformats = { "unix", "dos" }

-- Prettier só formata quando o projeto tem config de prettier; projetos com biome.json(c) usam Biome
vim.g.lazyvim_prettier_needs_config = true

-- Raiz do projeto: prioriza marcadores das stacks usadas (Unity/Unreal/.NET/monorepos)
vim.g.root_spec = {
  "lsp",
  { ".git", "lua", "*.uproject", "ProjectSettings", "*.sln", "pnpm-workspace.yaml" },
  "cwd",
}

-- Filetypes de Unreal/Unity (fica aqui, e não em autocmds.lua, para valer já no primeiro arquivo aberto)
vim.filetype.add({
  extension = {
    usf = "hlsl", -- Unreal shaders
    ush = "hlsl",
    shader = "shaderlab", -- Unity ShaderLab: highlight HLSL, sem LSP (ver register abaixo)
    cginc = "hlsl",
    compute = "hlsl",
    hlsl = "hlsl",
    hlsli = "hlsl",
    uproject = "json",
    uplugin = "json",
    uxml = "xml", -- Unity UI Toolkit
    uss = "css",
    tss = "css",
    asmdef = "json",
    asmref = "json",
    inputactions = "json",
  },
})

vim.treesitter.language.register("hlsl", "shaderlab")

-- fundo transparente (opacidade vem do Windows Terminal); registrado antes do tema ser aplicado
require("config.transparency").setup()

-- Ortografia (markdown/gitcommit/text, ligada pelo LazyVim): inglês + português do Brasil
vim.opt.spelllang = { "en", "pt_br" }

vim.opt.relativenumber = true
vim.opt.scrolloff = 8
