# Build a prismio compiler generation from the repository sources.
#
#   .\tools\bootstrap.ps1 -Out build\gen0.exe                        # from the seed
#   .\tools\bootstrap.ps1 -Compiler build\gen0.exe -Out build\gen1.exe
#
# Why this exists: the repository previously had no build script at all, so the
# only way to rebuild the compiler was `prismio build src\main.psm`, which asks the
# *bootstrapping* binary to supply the runtime -- from the copy embedded inside
# itself, not from runtime\ on disk. Edits to runtime sources were therefore
# invisible to the next generation unless embedded_sources.h was regenerated and
# the old compiler rebuilt first. This script sidesteps that by doing the link by
# hand: the frontend produces IR, and every runtime source is compiled fresh from
# the working tree.
#
# runtime.c is deliberately absent from the source list -- it no longer exists. It
# used to be a full-text #include of the other runtime sources and would have
# collided with them at link time.
#
# Requires llc and clang on PATH, plus a C toolchain clang can find headers for
# (on Windows: MSVC Build Tools with the Windows SDK).

param(
    # One of -Compiler or -Seed is required. -Seed starts from
    # bootstrap\prismio-seed.ll, committed LLVM IR for the compiler, which is the
    # only way to build a first compiler on a machine that has none (or whose only
    # prismio is an older generation you no longer trust). Pass a path to use a
    # different seed. Mirrors --seed in tools/bootstrap.sh.
    [string]$Compiler = '',
    [string]$Seed = '',
    [Parameter(Mandatory = $true)][string]$Out,
    # Defaults to the repository root (this script's parent directory). Resolved in
    # the body, not here: $PSScriptRoot is not populated during param binding.
    [string]$Repo = '',
    [switch]$KeepIntermediates
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($Repo)) { $Repo = Split-Path -Parent $PSScriptRoot }

# Must match prismio_toolchain_files[] in runtime\build_driver.c.
$runtimeSources = @('lang_runtime.c', 'program_support.c', 'build_driver.c', 'llvm-bridge.c')

$work = Join-Path (Split-Path -Parent $Out) ('.bootstrap-' + [System.IO.Path]::GetFileNameWithoutExtension($Out))
New-Item -ItemType Directory -Force $work | Out-Null

function Invoke-Step {
    # NB: not $Args -- that is a PowerShell automatic variable and cannot be bound.
    param([string]$Label, [string]$Exe, [string[]]$CmdArgs)
    Write-Host "[$Label]" -ForegroundColor DarkGray
    $output = & $Exe @CmdArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED: $Label" -ForegroundColor Red
        $output | ForEach-Object { Write-Host "  $_" }
        exit 1
    }
}

$ll = Join-Path $work 'compiler.ll'

# 1. Obtain IR for the compiler. With no -Compiler there is nothing to run the
# frontend with, so fall back to the seed -- that is exactly the situation it is
# committed for.
if ([string]::IsNullOrEmpty($Compiler)) {
    if ([string]::IsNullOrEmpty($Seed)) { $Seed = Join-Path $Repo 'bootstrap\prismio-seed.ll' }
    if (-not (Test-Path $Seed)) { Write-Host "FAILED: seed not found: $Seed" -ForegroundColor Red; exit 1 }
    Write-Host '[seed -> ll]' -ForegroundColor DarkGray
    Copy-Item $Seed $ll -Force
} else {
    Invoke-Step 'psm -> ll' $Compiler @('build', (Join-Path $Repo 'src\main.psm'), '-o', $ll)
    if (-not (Test-Path $ll)) { Write-Host 'FAILED: no IR produced' -ForegroundColor Red; exit 1 }
}

# Duplicate symbols mean import resolution merged a module more than once. llc would
# reject them anyway, but name them explicitly so the cause is obvious.
$syms = Select-String -Path $ll -Pattern '^(define|declare).*?@([A-Za-z0-9_.$]+)\(' |
        ForEach-Object { $_.Matches[0].Groups[2].Value }
$dupes = $syms | Group-Object | Where-Object Count -gt 1
if ($dupes) {
    Write-Host "DUPLICATE SYMBOLS IN IR ($($dupes.Count)):" -ForegroundColor Red
    $dupes | Sort-Object Count -Descending | Select-Object -First 20 |
        ForEach-Object { Write-Host ("  {0} x{1}" -f $_.Name, $_.Count) -ForegroundColor Red }
    exit 1
}
Write-Host "IR: $($syms.Count) symbols, all unique" -ForegroundColor Green

# 2. Backend: IR -> object.
$programObj = Join-Path $work 'program.obj'
Invoke-Step 'll -> obj' 'llc' @($ll, '-filetype=obj', '-o', $programObj)

# 3. Runtime and backend C sources, compiled fresh from the working tree.
$objs = @($programObj)
foreach ($c in $runtimeSources) {
    $obj = Join-Path $work ([System.IO.Path]::GetFileNameWithoutExtension($c) + '.obj')
    Invoke-Step "cc $c" 'clang' @('-Wno-deprecated-declarations', '-c', (Join-Path $Repo "runtime\$c"), '-o', $obj)
    $objs += $obj
}

# 4. Link.
Invoke-Step 'link' 'clang' ($objs + @('-o', $Out))

if (-not $KeepIntermediates) { Remove-Item $work -Recurse -Force }
Write-Host "Built $Out ($((Get-Item $Out).Length) bytes)" -ForegroundColor Green
