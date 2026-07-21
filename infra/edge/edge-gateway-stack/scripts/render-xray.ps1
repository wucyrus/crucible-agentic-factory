param(
    [string]$RootDir = (Resolve-Path (Join-Path $PSScriptRoot ".."))
)

$ErrorActionPreference = "Stop"

Set-Location $RootDir

$envFile = Join-Path $RootDir ".env"
if (-not (Test-Path $envFile)) {
    Write-Error "Error: .env not found in $RootDir. Tip: copy .env.example to .env"
}

function Get-DotEnvMap {
    param([string]$Path)

    $map = @{}
    foreach ($line in Get-Content -Path $Path) {
        $trimmed = $line.Trim()
        if ($trimmed -eq "" -or $trimmed.StartsWith("#")) {
            continue
        }

        $parts = $trimmed -split "=", 2
        if ($parts.Count -ne 2) {
            continue
        }

        $key = $parts[0].Trim()
        $value = $parts[1].Trim()
        if ($key -ne "") {
            $map[$key] = $value
        }
    }

    return $map
}

function Render-Template {
    param(
        [string]$InputPath,
        [string]$OutputPath,
        [hashtable]$Vars
    )

    $text = Get-Content -Path $InputPath -Raw
    $rendered = [regex]::Replace($text, '\$\{([A-Za-z_][A-Za-z0-9_]*)\}', {
        param($m)
        $name = $m.Groups[1].Value
        if ($Vars.ContainsKey($name)) {
            return [string]$Vars[$name]
        }

        # Keep unresolved placeholders as-is; they are checked after rendering.
        return $m.Value
    })

    Set-Content -Path $OutputPath -Value $rendered -NoNewline
}

$vars = Get-DotEnvMap -Path $envFile

$outputDir = Join-Path $RootDir "xray/output"
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

$templates = @(
    @{ In = (Join-Path $RootDir "xray/server-config.json"); Out = (Join-Path $outputDir "server-config.json") },
    @{ In = (Join-Path $RootDir "xray/client-config.json"); Out = (Join-Path $outputDir "client-config.json") }
)

foreach ($t in $templates) {
    Render-Template -InputPath $t.In -OutputPath $t.Out -Vars $vars
}

$remaining = Select-String -Path (Join-Path $outputDir "*.json") -Pattern '\$\{' -SimpleMatch:$false
if ($remaining) {
    Write-Error "Warning: unresolved placeholders remain in xray/output files."
}

Write-Host "Rendered files:"
Write-Host "- xray/output/server-config.json"
Write-Host "- xray/output/client-config.json"
