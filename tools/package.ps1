# Assemble an installed Prismio toolchain:
#
#   <OutDir>/bin/prismio.exe
#   <OutDir>/lib/runtime.lib     linked into every compiled program
#   <OutDir>/lib/backend.lib     linked into the compiler only
#   <OutDir>/stdlib/
#
#   .\tools\package.ps1 -Compiler build\prismio.exe -OutDir dist\Prismio
#
# The runtime/backend split is enforced here, at the point the libraries are built:
# runtime.lib gets lang_runtime.c + program_support.c, backend.lib gets
# build_driver.c + ir_symbols.c + diagnostics.c + llvm-api-backend.c. Because a compiled program
# links only runtime.lib
# (see find_toolchain_library / link_against_runtime_library in build_driver.c),
# no ir_* backend symbol can reach a user binary -- tools\verify_separation.ps1
# checks that against the produced artifacts.

param(
    [Parameter(Mandatory = $true)][string]$Compiler,
    [Parameter(Mandatory = $true)][string]$OutDir,
    [string]$Repo = ''
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrEmpty($Repo)) { $Repo = Split-Path -Parent $PSScriptRoot }

# Must match prismio_toolchain_files[] in runtime\build_driver.c.
$libraries = @(
    @{ Name = 'runtime'; Sources = @('lang_runtime.c', 'program_support.c') },
    @{ Name = 'backend'; Sources = @('build_driver.c', 'ir_symbols.c', 'aif_support.c', 'diagnostics.c', 'llvm-api-backend.c') }
)

# Absolute: the compiler is invoked from $Repo further down, and the final listing
# slices $OutDir off full paths -- both of which mangle a relative -OutDir.
New-Item -ItemType Directory -Force $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path
$Compiler = (Resolve-Path $Compiler).Path

$bin = Join-Path $OutDir 'bin'
$lib = Join-Path $OutDir 'lib'
$stdlib = Join-Path $OutDir 'stdlib'
$work = Join-Path $OutDir '.objs'
New-Item -ItemType Directory -Force $bin, $lib, $stdlib, $work | Out-Null

function Invoke-Step {
    param([string]$Label, [string]$Exe, [string[]]$CmdArgs)
    $output = & $Exe @CmdArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED: $Label" -ForegroundColor Red
        $output | ForEach-Object { Write-Host "  $_" }
        exit 1
    }
}

# On Windows produce MSVC-style .lib via llvm-lib; elsewhere GNU-style .a via ar.
# find_toolchain_library() accepts either, preferring the platform-native one, so a
# toolchain packaged on one platform still resolves if copied to another.
$onWindows = $env:OS -eq 'Windows_NT'
$archiveExt = if ($onWindows) { '.lib' } else { '.a' }

foreach ($entry in $libraries) {
    $objs = @()
    foreach ($src in $entry.Sources) {
        $obj = Join-Path $work ([System.IO.Path]::GetFileNameWithoutExtension($src) + '.obj')
        Invoke-Step "cc $src" 'clang' @('-Wno-deprecated-declarations', '-c', (Join-Path $Repo "runtime\$src"), '-o', $obj)
        $objs += $obj
    }

    $archive = Join-Path $lib ($entry.Name + $archiveExt)
    if (Test-Path $archive) { Remove-Item -LiteralPath $archive -Force }

    if ($onWindows) {
        Invoke-Step "lib $($entry.Name)" 'llvm-lib' (@("/OUT:$archive") + $objs)
    } else {
        Invoke-Step "ar $($entry.Name)" 'ar' (@('rcs', $archive) + $objs)
    }

    Write-Host ("  {0,-12} {1,8:N0} bytes  <- {2}" -f (Split-Path -Leaf $archive), (Get-Item $archive).Length, ($entry.Sources -join ' + ')) -ForegroundColor Green
}

Copy-Item $Compiler (Join-Path $bin 'prismio.exe') -Force
Remove-Item $work -Recurse -Force

# Record what runtime.lib was built from, so a later build can tell whether the
# library still matches the sources. Computed by the compiler itself
# (`prismio runtime-hash`) rather than reimplemented here, so the packaging step and
# the freshness check can never disagree about how the hash is derived.
Push-Location $Repo
try {
    $runtimeHash = (& $Compiler runtime-hash 2>&1 | Select-Object -Last 1).ToString().Trim()
    if ($LASTEXITCODE -ne 0 -or $runtimeHash -notmatch '^[0-9a-f]{16}$') {
        Write-Host "FAILED: could not compute runtime hash ($runtimeHash)" -ForegroundColor Red
        exit 1
    }
} finally { Pop-Location }
Set-Content (Join-Path $lib 'runtime.hash') $runtimeHash -Encoding ascii -NoNewline
Write-Host ("  {0,-12} {1}" -f 'runtime.hash', $runtimeHash) -ForegroundColor Green

# stdlib/ is part of the published layout but has no content yet: Prismio has no
# module library, only the runtime externs declared per-file in .psm source.
$readme = Join-Path $stdlib 'README.md'
if (-not (Test-Path $readme)) {
    Set-Content $readme "# stdlib`n`nReserved for the Prismio module library. Empty for now -- the language currently`nexposes runtime functionality through `extern fn` declarations resolved against`nruntime.lib, not through importable stdlib modules.`n" -Encoding ascii
}

Write-Host "Packaged toolchain at $OutDir" -ForegroundColor Green
Get-ChildItem $OutDir -Recurse -File | ForEach-Object {
    Write-Host ("  {0}" -f $_.FullName.Substring($OutDir.Length + 1))
}
