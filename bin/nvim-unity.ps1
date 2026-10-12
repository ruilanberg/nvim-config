# Abre arquivos do Unity no Neovim, reaproveitando uma instância por projeto.
# Chamado pelo pacote com.maneuver.nvim (Vim Client Path -> nvim-unity.cmd) com: nvim +LINHA "ARQUIVO"
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest)

$line = 1
$file = $null
foreach ($a in $Rest) {
    if ($a -eq 'nvim') { continue }
    if ($a -match '^\+(\d+)$') { $line = [int]$Matches[1]; continue }
    $file = $a
}
if (-not $file) { exit 1 }
$file = [IO.Path]::GetFullPath($file)

# Raiz do projeto Unity = pasta com Assets/ e ProjectSettings/ (pacotes locais fora do projeto usam a própria pasta)
$root = Split-Path $file -Parent
$dir = $root
while ($dir) {
    if ((Test-Path (Join-Path $dir 'Assets')) -and (Test-Path (Join-Path $dir 'ProjectSettings'))) { $root = $dir; break }
    $dir = Split-Path $dir -Parent
}

$name = Split-Path $root -Leaf
$id = ($name -replace '[^\w-]', '_')
$pipe = "\\.\pipe\nvim-unity-$id"
$title = "nvim-unity: $name"

$running = [IO.Directory]::GetFiles('\\.\pipe\') -contains $pipe
if ($running) {
    $vimPath = ($file -replace '\\', '/') -replace ' ', '\ '
    & nvim --server $pipe --remote-send "<C-\><C-N>:drop $vimPath<CR>:$line<CR>zz"
    $null = (New-Object -ComObject WScript.Shell).AppActivate($title)
} else {
    $wtArgs = @('-w', 'new', 'nt', '--title', "`"$title`"", '--suppressApplicationTitle', '-d', "`"$root`"",
        'nvim', '--listen', $pipe, "+$line", "`"$file`"")
    Start-Process wt.exe -ArgumentList $wtArgs
}
