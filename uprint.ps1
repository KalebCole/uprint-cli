#!/usr/bin/env pwsh
# uprint — Universal Print agentic CLI
# Usage: uprint <command> [options]

param(
    [Parameter(Position = 0)][string]$Command,
    [Parameter(Position = 1)][string]$SubCommand,
    [Parameter(ValueFromRemainingArguments)][string[]]$Args,
    [switch]$Json,
    [string]$Printer,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$scriptRoot = $PSScriptRoot

# Source all libraries
. "$scriptRoot\src\lib\Format-UPrintOutput.ps1"
. "$scriptRoot\src\lib\New-UPrintError.ps1"
. "$scriptRoot\src\lib\Get-UPrintConfig.ps1"

# Load config defaults
$config = Get-UPrintConfig
$printerName = if ($Printer) { $Printer } else { $config.defaultPrinter }
$useJson = $Json -or $config.jsonOutput

# Help text
$helpText = @"
uprint — Universal Print CLI for humans and AI agents

USAGE:
  uprint <command> [options]

COMMANDS:
  setup                 Interactive printer setup (run first!)
  printers              List available printers
  status                Show printer status
  print <file>          Print a file
  queue                 List print queue
  queue cancel <id>     Cancel a print job
  queue cancel --all    Cancel all print jobs
  health                Run diagnostic health check
  config get [key]      Show configuration
  config set <key> <v>  Set configuration value

GLOBAL FLAGS:
  --json                Output structured JSON
  --printer <name>      Target printer (default: $($config.defaultPrinter))
  --help                Show this help

EXAMPLES:
  uprint setup
  uprint printers --json
  uprint print report.pdf --printer Office-Printer-2
  uprint queue cancel --all
  uprint health --json
"@

if ($Help -or -not $Command) {
    Write-Output $helpText
    exit 0
}

# First-run guard — skip for setup and config commands
if (-not $config.defaultPrinter -and $Command -notin @('setup', 'config', $null)) {
    Write-Host "No default printer configured. Run 'uprint setup' to get started." -ForegroundColor Yellow
    exit 0
}

# Route commands
switch ($Command.ToLower()) {
    'setup' {
        . "$scriptRoot\src\commands\Invoke-UPrintSetup.ps1"
        Invoke-UPrintSetup -Json:$useJson
    }
    'printers' {
        . "$scriptRoot\src\commands\Get-UPrintPrinters.ps1"
        $params = @{ Json = $useJson }
        if ($Args -contains '--universal-only' -or $Args -contains '-u') { $params.UniversalOnly = $true }
        Get-UPrintPrinters @params
    }
    'status' {
        . "$scriptRoot\src\commands\Get-UPrintStatus.ps1"
        Get-UPrintStatus -PrinterName $printerName -Json:$useJson
    }
    'print' {
        . "$scriptRoot\src\commands\Invoke-UPrintPrint.ps1"
        if (-not $SubCommand) {
            Write-Error "Usage: uprint print <file> [--copies N] [--duplex] [--color|--mono]"
            exit 3
        }
        $params = @{ FilePath = $SubCommand; PrinterName = $printerName; Json = $useJson }
        # Parse optional flags from remaining args
        if ($Args) {
            if ($Args -contains '--duplex') { $params.Duplex = $true }
            if ($Args -contains '--mono') { $params.ColorMode = 'Mono' }
            if ($Args -contains '--color') { $params.ColorMode = 'Color' }
            $copiesIdx = [array]::IndexOf($Args, '--copies')
            if ($copiesIdx -ge 0 -and $copiesIdx -lt ($Args.Count - 1)) {
                $params.Copies = [int]$Args[$copiesIdx + 1]
            }
        }
        Invoke-UPrintPrint @params
    }
    'queue' {
        . "$scriptRoot\src\commands\Get-UPrintQueue.ps1"
        if ($SubCommand -eq 'cancel') {
            $cancelAll = $Args -contains '--all'
            $jobId = ($Args | Where-Object { $_ -match '^\d+$' } | Select-Object -First 1)
            $params = @{ PrinterName = $printerName; Cancel = $true; Json = $useJson }
            if ($cancelAll) { $params.CancelAll = $true }
            elseif ($jobId) { $params.JobId = [int]$jobId }
            Get-UPrintQueue @params
        } else {
            Get-UPrintQueue -PrinterName $printerName -Json:$useJson
        }
    }
    'health' {
        . "$scriptRoot\src\commands\Get-UPrintHealth.ps1"
        Get-UPrintHealth -PrinterName $printerName -Json:$useJson
    }
    'config' {
        if ($SubCommand -eq 'set' -and $Args.Count -ge 2) {
            $result = Set-UPrintConfig -Key $Args[0] -Value $Args[1]
            if ($useJson) {
                Format-UPrintOutput -Command 'config' -Data $result -Json
            } else {
                Write-Output "✅ Set $($Args[0]) = $($Args[1])"
            }
        } else {
            $cfg = Get-UPrintConfig
            if ($useJson) {
                Format-UPrintOutput -Command 'config' -Data $cfg -Json
            } else {
                $cfg | Format-Table -AutoSize
            }
        }
    }
    default {
        Write-Error "Unknown command: $Command. Run 'uprint --help' for usage."
        exit 1
    }
}
