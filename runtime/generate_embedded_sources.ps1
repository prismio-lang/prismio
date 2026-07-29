$ErrorActionPreference = "Stop"

# Read as raw bytes (not decoded text) so escaping is byte-accurate regardless of
# the source file's encoding -- avoids codepage mojibake from Get-Content -Raw.
function Read-Bytes([string]$path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $text = [System.Text.Encoding]::GetEncoding('ISO-8859-1').GetString($bytes)
    return $text -replace "`r`n", "`n" -replace "`r", "`n"
}

# Must stay in step with prismio_toolchain_files[] in build_driver.c. The two
# headers are embedded as well as the .c files because the unpacked sources
# include them.
$embeddedFiles = @(
    @{ File = 'prismio_platform.h'; Symbol = 'prismio_embedded_prismio_platform_h' },
    @{ File = 'prismio_runtime.h';  Symbol = 'prismio_embedded_prismio_runtime_h' },
    @{ File = 'lang_runtime.c';     Symbol = 'prismio_embedded_lang_runtime_c' },
    @{ File = 'program_support.c';  Symbol = 'prismio_embedded_program_support_c' },
    @{ File = 'build_driver.c';     Symbol = 'prismio_embedded_build_driver_c' },
    @{ File = 'llvm-bridge.c';      Symbol = 'prismio_embedded_llvm_bridge_c' }
)

$lines = New-Object System.Collections.Generic.List[string]

function Escape-Line([string]$line) {
    $builder = New-Object System.Text.StringBuilder
    foreach ($ch in $line.ToCharArray()) {
        $code = [int][char]$ch
        if ($ch -eq '\') {
            [void]$builder.Append('\\')
        } elseif ($ch -eq '"') {
            [void]$builder.Append('\"')
        } elseif ($ch -eq "`t") {
            [void]$builder.Append('\t')
        } elseif ($code -lt 32 -or $code -gt 126) {
            # C string escapes are octal (\nnn), not decimal.
            [void]$builder.Append('\' + [Convert]::ToString($code, 8).PadLeft(3, '0'))
        } else {
            [void]$builder.Append($ch)
        }
    }
    return $builder.ToString()
}

function Add-CString([string]$name, [string]$value) {
    $script:lines.Add("static const char $name[] =")
    $parts = $value.Split([string[]]@("`n"), [System.StringSplitOptions]::None)
    for ($i = 0; $i -lt $parts.Length; $i++) {
        $escaped = Escape-Line $parts[$i]
        if ($i -eq ($parts.Length - 1) -and $escaped.Length -eq 0) {
            continue
        }
        $script:lines.Add('"' + $escaped + '\n"')
    }
    $script:lines.Add(';')
    $script:lines.Add('')
}

$lines.Add('#ifndef PRISMIO_EMBEDDED_SOURCES_H')
$lines.Add('#define PRISMIO_EMBEDDED_SOURCES_H')
$lines.Add('')
$lines.Add('#define PRISMIO_EMBEDDED_SOURCE_AVAILABLE 1')
$lines.Add('')
foreach ($entry in $embeddedFiles) {
    $path = Join-Path $PSScriptRoot $entry.File
    if (-not (Test-Path -LiteralPath $path)) {
        throw "ERROR: missing toolchain source $path"
    }
    Add-CString $entry.Symbol (Read-Bytes $path)
}
$lines.Add('#endif')

Set-Content -LiteralPath "$PSScriptRoot\embedded_sources.h" -Value $lines -Encoding ASCII
