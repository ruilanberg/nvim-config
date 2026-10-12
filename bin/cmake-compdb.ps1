# Gera compile_commands.json para projetos CMake (MSVC + Ninja) sem mexer nos presets do projeto.
# Uso (na pasta do projeto):  cmake-compdb [-Source .] [-BuildDir build-clangd] [-Config Debug]
param(
    [string]$Source = (Get-Location).Path,
    [string]$BuildDir = 'build-clangd',
    [string]$Config = 'Debug'
)
$ErrorActionPreference = 'Stop'
$Source = (Resolve-Path $Source).Path
if (-not (Test-Path (Join-Path $Source 'CMakeLists.txt'))) { throw "CMakeLists.txt não encontrado em '$Source'." }

# Carrega o ambiente do MSVC (cl.exe, Windows SDK) se ainda não estiver carregado
if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) {
    $vs = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $vs) { throw 'Visual Studio com C++ não encontrado.' }
    # vcvars64.bat + importar o ambiente (o Launch-VsDevShell.ps1 quebra com mais de um VS instalado)
    $vcvars = Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'
    cmd /c "`"$vcvars`" >nul && set" | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') { Set-Item "env:$($Matches[1])" $Matches[2] }
    }
    if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) { throw "Falha ao carregar o ambiente do MSVC ($vcvars)." }
}

$build = Join-Path $Source $BuildDir
cmake -S $Source -B $build -G Ninja "-DCMAKE_BUILD_TYPE=$Config" -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_C_COMPILER=cl -DCMAKE_CXX_COMPILER=cl
if ($LASTEXITCODE -ne 0) { throw "CMake falhou (exit $LASTEXITCODE)." }

Copy-Item (Join-Path $build 'compile_commands.json') (Join-Path $Source 'compile_commands.json') -Force
Write-Host "OK: $(Join-Path $Source 'compile_commands.json')" -ForegroundColor Green
Write-Host "Dica: adicione compile_commands.json e $BuildDir/ ao .gitignore do projeto." -ForegroundColor DarkGray
