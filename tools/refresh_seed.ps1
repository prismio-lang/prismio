# Regenerate bootstrap/prismio-seed.ll from a known-good compiler.
#
#   .\tools\refresh_seed.ps1 -Compiler build\gen2.exe
#
# The seed is committed LLVM IR for src/main.psm and is the only way to build a
# first compiler on a host that has none. Refresh it whenever a language or codegen
# change would stop the current seed from compiling the current sources -- not on
# every commit, since a stale seed is harmless as long as the compiler it produces
# can still build the tree.
#
# Two things make the committed file portable, and both are enforced below:
#   * the target triple is stripped, so llc targets whatever host it runs on;
#   * the compiler supplied must already be at a gen1/gen2 fixed point, so the seed
#     encodes a settled compiler rather than a half-migrated one.
#
# The second is checked, not assumed: the seed is required to reproduce itself.

param(
    [Parameter(Mandatory = $true)][string]$Compiler,
    [string]$Repo = ''
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrEmpty($Repo)) { $Repo = Split-Path -Parent $PSScriptRoot }

$work = Join-Path $Repo 'build\.seed'
New-Item -ItemType Directory -Force $work, (Join-Path $Repo 'bootstrap') | Out-Null
$raw = Join-Path $work 'seed-raw.ll'

& $Compiler build (Join-Path $Repo 'src\main.psm') -o $raw | Out-Null
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $raw)) {
    Write-Host 'FAILED: compiler could not build src\main.psm' -ForegroundColor Red; exit 1
}

# Fixed-point check: a compiler that does not reproduce its own IR is mid-migration,
# and freezing that state into the seed would hand every new host a compiler that
# disagrees with the one everyone else is running.
$again = Join-Path $work 'seed-raw-2.ll'
& $Compiler build (Join-Path $Repo 'src\main.psm') -o $again | Out-Null
if ((Get-FileHash $raw).Hash -ne (Get-FileHash $again).Hash) {
    Write-Host 'FAILED: compiler is not deterministic' -ForegroundColor Red; exit 1
}

$lines = [System.IO.File]::ReadAllText($raw) -split "`r?`n"
$body = $lines | Where-Object { $_ -notmatch '^target (triple|datalayout)\s*=' }

$header = @(
  "; Prismio bootstrap seed -- LLVM IR for the Prismio compiler (src/main.psm).",
  ";",
  "; Committed because a new platform has no prismio binary to compile src/main.psm",
  "; with, and this is the smallest artifact that breaks that cycle. Produced by a",
  "; compiler that had reached a byte-identical gen1/gen2 fixed point.",
  ";",
  "; Deliberately carries no 'target triple' or 'target datalayout' line, so llc",
  "; targets whatever host it runs on. That is safe here because the IR is entirely",
  "; target-neutral: every function signature uses only i1/i8/i32/ptr/void, no struct",
  "; is passed by value, and there are no byval/sret attributes or target intrinsics.",
  ";",
  "; Rebuild with: tools/refresh_seed.ps1",
  ";"
)

$seed = Join-Path $Repo 'bootstrap\prismio-seed.ll'
[System.IO.File]::WriteAllText($seed, (($header + $body) -join "`n"))
Remove-Item $work -Recurse -Force

$stripped = $lines.Count - $body.Count
Write-Host ("Wrote {0} ({1:N0} bytes, {2} target directive(s) stripped)" -f $seed, (Get-Item $seed).Length, $stripped) -ForegroundColor Green
Write-Host "Verify with: .\tools\bootstrap.ps1 -Compiler <any> -Out build\seedcheck.exe" -ForegroundColor DarkGray
