# nvim

Config do Neovim (0.12+) baseada no [LazyVim](https://github.com/LazyVim/LazyVim), focada em desenvolvimento de jogos e web: Unity (C#), Unreal Engine e C++/CMake, TypeScript/Node. Feita para abrir rápido (~125 ms) e deixar o pesado para depois do primeiro desenho.

## Instalação

```sh
# Windows
git clone https://github.com/ruilanberg/nvim-config $env:LOCALAPPDATA\nvim
# Linux / macOS
git clone https://github.com/ruilanberg/nvim-config ~/.config/nvim
```

Requisitos: git, um compilador C (para os parsers do treesitter), `tree-sitter-cli` (o Mason instala), ripgrep, fd, lazygit e uma Nerd Font no terminal. No Windows: PowerShell 7 (instalador MSI) e o clangd do LLVM no PATH.

## O que tem além do LazyVim

| Área | Arquivo | Destaques |
|---|---|---|
| C# / Unity | `lua/plugins/csharp.lua` | Roslyn LSP (`roslyn.nvim`), prefere o `.sln` gerado pelo Unity |
| C++ / CMake | `lua/plugins/cpp.lua` | clangd ajustado para Unreal, `cmake-tools.nvim` + codelldb (`<leader>m*`) |
| Unreal | `lua/config/unreal.lua` | `:UnrealBuild [Development\|DebugGame]` (`<leader>cb`), erros na quickfix; Windows, Linux e Mac |
| Unreal (debug) | `lua/plugins/unreal-debug.lua` | `:UnrealAttach` anexa o codelldb ao editor aberto (só Windows) |
| clangd | `lua/config/compdb.lua` | regenera o `compile_commands.json` de projetos Unreal/CMake quando fica desatualizado (`:CompdbRefresh`) |
| Web | `lua/plugins/web.lua` | Tailwind dentro de `cn()`/`cva()`/`clsx()`/`tv()` |
| Shaders etc. | `lua/config/options.lua`, `lua/plugins/langs.lua` | HLSL/USF/ShaderLab, UXML/USS, Protobuf, PowerShell |
| Abertura rápida | `lua/config/fastopen.lua` | treesitter e LSP sobem logo depois do arquivo aparecer |
| Visual | `lua/plugins/colorscheme.lua`, `lua/config/transparency.lua` | tema fluoromachine, fundo transparente (`<leader>uo`, desliga sozinho durante o debug) |
| Extras | `lazyvim.json` | Claude Code (`<leader>a*`), harpoon (`<leader>H`, `<leader>1-9`), ortografia en + pt_br |

## Observações

- No Windows, o `compdb.lua` usa os scripts `ue-compdb.ps1` e `cmake-compdb.ps1` de `~/.local/bin`, que não fazem parte deste repositório. No Linux e no Mac ele chama o UBT/CMake direto.
- Se a engine do Unreal estiver fora do lugar padrão, defina `UE_ROOT`.
