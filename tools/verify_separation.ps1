# Verify the runtime/backend boundary against real artifacts.
#
#   .\tools\verify_separation.ps1 -Dist dist\Prismio
#
# The rule being checked: the LLVM backend is a compiler-only component. A program
# compiled by Prismio links runtime.lib and nothing else, so no backend symbol may
# appear in a user binary -- while the compiler itself must contain the backend.
#
# Two independent checks, because they can fail separately:
#   1. Archive symbol tables (llvm-nm) -- proves the libraries were built from the
#      right translation units in the first place.
#   2. A byte signature in the produced executable -- proves the *link step* only
#      pulled in the runtime. A linked PE has no symbol table, so nm cannot answer
#      this one; instead look for IR-emitter format strings that exist only in
#      llvm-bridge.c (e.g. "  %%t%d = icmp %s %s %s, %s").

param(
    [Parameter(Mandatory = $true)][string]$Dist,
    [string]$Repo = ''
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrEmpty($Repo)) { $Repo = Split-Path -Parent $PSScriptRoot }

$failures = 0
function Check([string]$label, [bool]$ok, [string]$detail) {
    if ($ok) {
        Write-Host ("  [PASS] {0}{1}" -f $label, $(if ($detail) { " -- $detail" } else { '' })) -ForegroundColor Green
    } else {
        Write-Host ("  [FAIL] {0}{1}" -f $label, $(if ($detail) { " -- $detail" } else { '' })) -ForegroundColor Red
        $script:failures++
    }
}

function Get-ArchiveSymbols([string]$archive) {
    return (& llvm-nm --defined-only $archive 2>$null) -join "`n"
}

Write-Host "Archive contents"
# Archives only -- lib/ also holds the runtime.hash sidecar.
$archive = { $_.Extension -in @('.lib', '.a') }
$runtimeLib = Get-ChildItem (Join-Path $Dist 'lib') -Filter 'runtime.*' | Where-Object $archive | Select-Object -First 1
$backendLib = Get-ChildItem (Join-Path $Dist 'lib') -Filter 'backend.*' | Where-Object $archive | Select-Object -First 1
Check 'runtime library exists' ($null -ne $runtimeLib) $(if ($runtimeLib) { $runtimeLib.Name })
Check 'backend library exists' ($null -ne $backendLib) $(if ($backendLib) { $backendLib.Name })

if ($runtimeLib -and $backendLib) {
    $runtimeSyms = Get-ArchiveSymbols $runtimeLib.FullName
    $backendSyms = Get-ArchiveSymbols $backendLib.FullName

    $irInRuntime = ([regex]::Matches($runtimeSyms, '(?m)^\S+\s+[TtDdBb]\s+ir_[a-z]')).Count
    $irInBackend = ([regex]::Matches($backendSyms, '(?m)^\S+\s+[TtDdBb]\s+ir_[a-z]')).Count
    Check 'runtime library defines no ir_* backend symbols' ($irInRuntime -eq 0) "found $irInRuntime"
    Check 'backend library defines the ir_* backend symbols' ($irInBackend -gt 0) "found $irInBackend"

    $cliInRuntime = $runtimeSyms -match 'cli_arg_count'
    $buildInBackend = $backendSyms -match 'compiler_build_executable'
    Check 'runtime library provides cli_arg_count' $cliInRuntime
    Check 'backend library provides compiler_build_executable' $buildInBackend
    Check 'runtime library does NOT provide compiler_build_executable' (-not ($runtimeSyms -match 'compiler_build_executable'))
}

Write-Host "`nCompiled user program"
$prismio = Join-Path $Dist 'bin\prismio.exe'
$probeSrc = Join-Path $env:TEMP 'prismio_sep_probe.psm'
$probeExe = Join-Path $env:TEMP 'prismio_sep_probe.exe'
Set-Content $probeSrc "fn main() -> Int {`n    println(`"ok`")`n    return 0`n}" -Encoding ascii

# Build from a directory with no runtime/ anywhere nearby, so a source-based build
# could only succeed via sources embedded in the binary -- which the signature check
# below would then catch.
Push-Location $env:TEMP
try {
    $out = & $prismio build $probeSrc -o $probeExe 2>&1
    Check 'installed toolchain compiles a program' ($LASTEXITCODE -eq 0) ($out -join ' ')
} finally { Pop-Location }

if (Test-Path $probeExe) {
    Check 'compiled program runs' ((& $probeExe) -eq 'ok')

    # Format strings that only llvm-bridge.c contributes.
    $signatures = @('getelementptr', 'icmp ', 'alloca ')
    $bytes = [System.IO.File]::ReadAllBytes($probeExe)
    $text = [System.Text.Encoding]::ASCII.GetString($bytes)
    $hits = @()
    foreach ($sig in $signatures) {
        $n = ([regex]::Matches($text, [regex]::Escape($sig))).Count
        if ($n -gt 0) { $hits += "$sig x$n" }
    }
    Check 'no LLVM backend code in the user binary' ($hits.Count -eq 0) $(if ($hits) { $hits -join ', ' } else { 'clean' })

    # Sanity: the same signatures must be present in the compiler, otherwise the
    # check above would pass trivially for the wrong reason.
    $compilerText = [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($prismio))
    $compilerHits = ([regex]::Matches($compilerText, 'getelementptr')).Count
    Check 'the compiler itself does contain the backend' ($compilerHits -gt 0) "getelementptr x$compilerHits"

    Remove-Item -LiteralPath $probeExe -Force -ErrorAction SilentlyContinue
}
Remove-Item -LiteralPath $probeSrc -Force -ErrorAction SilentlyContinue

Write-Host ""
if ($failures -gt 0) {
    Write-Host "$failures check(s) FAILED" -ForegroundColor Red
    exit 1
}
Write-Host "All separation checks passed" -ForegroundColor Green
exit 0
