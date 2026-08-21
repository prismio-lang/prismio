# Install a packaged Prismio toolchain over an existing installation.
#
#   Run from an ELEVATED PowerShell (writing to Program Files needs admin):
#     .\tools\install.ps1 -Dist build\dist
#
# Layout note: the compiler locates its libraries relative to its own executable,
# trying <exe_dir>\..\lib\ and then <exe_dir>\lib\ (find_in_lib_dir in
# runtime\build_driver.c). The existing install at C:\Program Files\Prismio is flat
# -- prismio.exe sits alongside clang.exe, llc.exe and the rest of LLVM, all of
# which are on PATH -- so this installs prismio.exe at the top level and the
# archives into a lib\ subdirectory beside it. That hits the second probe and
# leaves the LLVM tools where PATH already expects them.
#
# Without lib\, the compiler still works: it falls back to compiling the runtime
# from sources embedded in the binary. That fallback is silent, which is exactly
# why this script verifies afterwards that the installed libraries are the ones
# actually being used.

param(
    [Parameter(Mandatory = $true)][string]$Dist,
    [string]$Prefix = 'C:\Program Files\Prismio'
)

$ErrorActionPreference = 'Stop'
$Dist = (Resolve-Path $Dist).Path

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$elevated = ([Security.Principal.WindowsPrincipal]$identity).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $elevated) {
    Write-Host "This needs an elevated PowerShell -- $Prefix is not writable otherwise." -ForegroundColor Yellow
    Write-Host "Re-run from a terminal started with 'Run as administrator'." -ForegroundColor Yellow
    exit 1
}

$exeSrc = Join-Path $Dist 'bin\prismio.exe'
if (-not (Test-Path $exeSrc)) { Write-Host "no prismio.exe in $Dist\bin" -ForegroundColor Red; exit 1 }

New-Item -ItemType Directory -Force $Prefix, (Join-Path $Prefix 'lib') | Out-Null

# Keep the outgoing binary so a bad install can be undone.
$exeDest = Join-Path $Prefix 'prismio.exe'
$backup  = Join-Path $Prefix 'prismio.exe.bak'
if ((Test-Path $exeDest) -and -not (Test-Path $backup)) {
    Copy-Item $exeDest $backup -Force
    Write-Host "  backed up previous prismio.exe -> prismio.exe.bak"
}

Copy-Item $exeSrc $exeDest -Force
Write-Host ("  prismio.exe  {0:N0} bytes" -f (Get-Item $exeDest).Length)
foreach ($f in 'runtime.lib', 'backend.lib', 'runtime.hash') {
    $from = Join-Path $Dist "lib\$f"
    if (Test-Path $from) {
        Copy-Item $from (Join-Path $Prefix "lib\$f") -Force
        Write-Host ("  lib\{0,-14} {1,10:N0} bytes" -f $f, (Get-Item (Join-Path $Prefix "lib\$f")).Length)
    }
}

# Verify from a directory with no repository nearby, so nothing resolves by accident.
Write-Host "`nVerifying..."
$probeSrc = Join-Path $env:TEMP 'prismio_install_probe.psm'
$probeExe = Join-Path $env:TEMP 'prismio_install_probe.exe'
# std.io is an ordinary import rather than a prelude as of 2026-08-21. Without the
# import this probe does not compile, and the installer reports a good install as
# a broken compiler and exits 1.
Set-Content $probeSrc "import std.io`n`nfn main() -> Int {`n    println(`"ok`")`n    return 0`n}" -Encoding ascii
Push-Location $env:TEMP
try {
    & $exeDest build $probeSrc -o $probeExe | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Host "  [FAIL] installed compiler cannot build a program" -ForegroundColor Red; exit 1 }
} finally { Pop-Location }
if ((& $probeExe) -ne 'ok') { Write-Host "  [FAIL] compiled program did not run" -ForegroundColor Red; exit 1 }
Write-Host "  [PASS] compiles and runs a program" -ForegroundColor Green

# The runtime hash the compiler computes from sources must match what was recorded
# when the libraries were built. A mismatch means lib\ is stale relative to the
# runtime sources -- the staleness this whole layout exists to make visible.
$recorded = (Get-Content (Join-Path $Prefix 'lib\runtime.hash') -Raw).Trim()
Write-Host "  [INFO] installed runtime.hash = $recorded"

Remove-Item $probeSrc, $probeExe -Force -ErrorAction SilentlyContinue
Write-Host "`nInstalled to $Prefix" -ForegroundColor Green
Write-Host "Revert with: Copy-Item '$backup' '$exeDest' -Force" -ForegroundColor DarkGray
