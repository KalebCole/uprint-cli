function Get-UPrintConfig {
    [CmdletBinding()]
    param()

    $configPath = Join-Path $env:USERPROFILE '.uprint' 'config.json'

    $defaults = @{
        defaultPrinter = $null
        autoWake       = $true
        timeout        = 10000
        jsonOutput     = $false
    }

    if (Test-Path $configPath) {
        try {
            $fileConfig = Get-Content $configPath -Raw | ConvertFrom-Json -AsHashtable
            foreach ($key in $fileConfig.Keys) {
                $defaults[$key] = $fileConfig[$key]
            }
        } catch {
            Write-Warning "Failed to parse config at $configPath, using defaults"
        }
    }

    return $defaults
}

function Set-UPrintConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Value
    )

    $configDir = Join-Path $env:USERPROFILE '.uprint'
    $configPath = Join-Path $configDir 'config.json'

    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    $config = @{}
    if (Test-Path $configPath) {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json -AsHashtable
    }

    # Type coercion: booleans and integers
    if ($Value -eq 'true') { $Value = $true }
    elseif ($Value -eq 'false') { $Value = $false }
    elseif ($Value -match '^\d+$') { $Value = [int]$Value }

    $config[$Key] = $Value
    $config | ConvertTo-Json -Depth 5 | Set-Content $configPath

    return $config
}
