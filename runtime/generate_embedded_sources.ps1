$ErrorActionPreference = "Stop"

$runtime = (Get-Content -Raw -LiteralPath "$PSScriptRoot\runtime.c") -replace "`r`n", "`n" -replace "`r", "`n"
$bridge = (Get-Content -Raw -LiteralPath "$PSScriptRoot\llvm-bridge.c") -replace "`r`n", "`n" -replace "`r", "`n"
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
            [void]$builder.Append(('\{0:D3}' -f $code))
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
Add-CString 'prismio_embedded_runtime_c' $runtime
Add-CString 'prismio_embedded_llvm_bridge_c' $bridge
$lines.Add('#endif')

Set-Content -LiteralPath "$PSScriptRoot\embedded_sources.h" -Value $lines -Encoding ASCII
