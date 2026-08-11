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
            $fileConfig = Get-Content $configPath -Raw | ConvertFrom-Json
            foreach ($property in $fileConfig.PSObject.Properties) {
                if ($defaults.ContainsKey($property.Name)) {
                    $defaults[$property.Name] = $property.Value
                }
            }
        } catch {
            [Console]::Error.WriteLine(
                "Warning: Failed to parse config at $configPath, using defaults"
            )
        }
    }

    return $defaults
}

function Set-UPrintConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][object]$Value
    )

    $configDir = Join-Path $env:USERPROFILE '.uprint'
    $configPath = Join-Path $configDir 'config.json'

    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    $config = Get-UPrintConfig

    if ($Key -in @('autoWake', 'jsonOutput')) {
        $Value = $Value -eq 'true'
    }
    elseif ($Key -eq 'timeout') {
        $Value = [int]$Value
    }
    else {
        $Value = [string]$Value
    }

    $config[$Key] = $Value
    $config | ConvertTo-Json -Depth 5 | Set-Content $configPath

    return $config
}
