# Gera compile_commands.json de um projeto Unreal para o clangd.
# Uso (na pasta do projeto ou passando o caminho):  ue-compdb [-Project <pasta|.uproject>] [-Config Development]
param(
    [string]$Project = (Get-Location).Path,
    [string]$Config = 'Development'
)
$ErrorActionPreference = 'Stop'

$uproject = if ($Project -like '*.uproject') { Get-Item $Project } else { Get-ChildItem $Project -Filter *.uproject | Select-Object -First 1 }
if (-not $uproject) { throw "Nenhum .uproject encontrado em '$Project'." }
$root = $uproject.DirectoryName
$name = $uproject.BaseName

# Localiza a engine pela EngineAssociation do .uproject (ex.: "5.8")
$assoc = (Get-Content $uproject.FullName -Raw | ConvertFrom-Json).EngineAssociation
$engine = (Get-ItemProperty "HKLM:\SOFTWARE\EpicGames\Unreal Engine\$assoc" -ErrorAction SilentlyContinue).InstalledDirectory
if (-not $engine) { $engine = "C:\Program Files\Epic Games\UE_$assoc" }
# Builds do Launcher não trazem RunUBT.bat; o UnrealBuildTool.exe existe em ambas
$ubt = @(
    (Join-Path $engine 'Engine\Binaries\DotNET\UnrealBuildTool\UnrealBuildTool.exe'),
    (Join-Path $engine 'Engine\Build\BatchFiles\RunUBT.bat')
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $ubt) { throw "UnrealBuildTool não encontrado em '$engine'." }

Write-Host "Engine: $engine`nTarget: ${name}Editor Win64 $Config" -ForegroundColor Cyan
& $ubt -mode=GenerateClangDatabase "-project=$($uproject.FullName)" "${name}Editor" Win64 $Config "-OutputDir=$root"
if ($LASTEXITCODE -ne 0) { throw "UBT falhou (exit $LASTEXITCODE)." }

# Versões antigas do UBT ignoram -OutputDir e gravam na raiz da engine
$out = Join-Path $root 'compile_commands.json'
$engineOut = Join-Path $engine 'compile_commands.json'
if (-not (Test-Path $out) -and (Test-Path $engineOut)) { Move-Item $engineOut $out -Force }

Write-Host "OK: $out" -ForegroundColor Green
Write-Host "Dica: adicione compile_commands.json e .cache/ ao .gitignore do projeto." -ForegroundColor DarkGray
