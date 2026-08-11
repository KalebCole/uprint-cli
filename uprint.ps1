#!/usr/bin/env pwsh
# uprint — Universal Print agentic CLI
# Usage: uprint <command> [options]

param(
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$CliArguments
)

$ErrorActionPreference = 'Stop'
$scriptRoot = $PSScriptRoot

$positionals = [System.Collections.Generic.List[string]]::new()
$Json = $false
$Printer = $null
$Help = $false
$argumentError = $null

for ($index = 0; $index -lt $CliArguments.Count; $index++) {
    switch ($CliArguments[$index]) {
        '--json' {
            $Json = $true
        }
        '--printer' {
            if ($index -ge ($CliArguments.Count - 1) -or
                $CliArguments[$index + 1] -match '^-') {
                $argumentError = @{
                    message    = '--printer requires a value'
                    suggestion = "Use '--printer <name>'"
                }
            } else {
                $Printer = $CliArguments[$index + 1]
                $index++
            }
        }
        '--help' {
            $Help = $true
        }
        default {
            $positionals.Add($CliArguments[$index])
        }
    }
}

$Command = if ($positionals.Count -gt 0) { $positionals[0] } else { $null }
$SubCommand = if ($positionals.Count -gt 1) { $positionals[1] } else { $null }
$Args = @()
if ($positionals.Count -gt 2) {
    $Args = [string[]]$positionals.GetRange(2, $positionals.Count - 2)
}

# Source all libraries
. "$scriptRoot\src\lib\Format-UPrintOutput.ps1"
. "$scriptRoot\src\lib\New-UPrintError.ps1"
. "$scriptRoot\src\lib\Get-UPrintConfig.ps1"

# Load config defaults
$config = Get-UPrintConfig
$printerName = if ($Printer) { $Printer } else { $config.defaultPrinter }
$useJson = $Json -or $config.jsonOutput

if ($argumentError) {
    $commandName = if ($Command) { $Command.ToLower() } else { 'invalid' }
    if ($useJson) {
        $err = New-UPrintError -Code 'INVALID_ARGUMENT' -Message $argumentError.message -Suggestion $argumentError.suggestion
        Format-UPrintOutput -Command $commandName -ErrorResult $err -Json
    } else {
        [Console]::Error.WriteLine("$($argumentError.message). $($argumentError.suggestion).")
    }
    exit 3
}

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
    if ($useJson) {
        $helpData = @{
            usage         = 'uprint <command> [options]'
            commands      = @('setup', 'printers', 'status', 'print', 'queue', 'health', 'config')
            globalOptions = @('--json', '--printer <name>', '--help')
        }
        Format-UPrintOutput -Command 'help' -Data $helpData -Json
    } else {
        Write-Output $helpText
    }
    exit 0
}

$knownCommands = @('setup', 'printers', 'status', 'print', 'queue', 'health', 'config')
if ($Command.ToLower() -notin $knownCommands) {
    $message = "Unknown command: $Command"
    if ($useJson) {
        $err = New-UPrintError -Code 'INVALID_ARGUMENT' -Message $message -Suggestion "Run 'uprint --help' for usage"
        Format-UPrintOutput -Command 'invalid' -ErrorResult $err -Json
    } else {
        [Console]::Error.WriteLine("$message. Run 'uprint --help' for usage.")
    }
    exit 3
}

# Commands that operate on one printer require an explicit or configured name.
$printerCommands = @('status', 'print', 'queue', 'health')
if (-not $printerName -and $Command.ToLower() -in $printerCommands) {
    $message = 'No printer selected'
    $suggestion = "Use --printer <name> or run 'uprint setup'"
    if ($useJson) {
        $err = New-UPrintError -Code 'INVALID_ARGUMENT' -Message $message -Suggestion $suggestion
        Format-UPrintOutput -Command $Command.ToLower() -ErrorResult $err -Json
    } else {
        [Console]::Error.WriteLine("$message. $suggestion.")
    }
    exit 3
}

# Route commands
switch ($Command.ToLower()) {
    'setup' {
        if ($useJson -and -not $Printer) {
            $message = 'setup requires --printer in JSON mode'
            $suggestion = "Use 'uprint setup --printer <name> --json'"
            $err = New-UPrintError -Code 'INVALID_ARGUMENT' -Message $message -Suggestion $suggestion
            Format-UPrintOutput -Command 'setup' -ErrorResult $err -Json
            exit 3
        }
        if (-not $useJson -and $Printer) {
            [Console]::Error.WriteLine('--printer requires JSON mode for setup.')
            exit 3
        }
        $unexpected = @($SubCommand) + @($Args) | Where-Object { $_ } | Select-Object -First 1
        if ($unexpected) {
            $message = "Unexpected argument: $unexpected"
            if ($useJson) {
                $err = New-UPrintError -Code 'INVALID_ARGUMENT' -Message $message -Suggestion "Run 'uprint --help' for usage"
                Format-UPrintOutput -Command 'setup' -ErrorResult $err -Json
            } else {
                [Console]::Error.WriteLine("$message. Run 'uprint --help' for usage.")
            }
            exit 3
        }
        . "$scriptRoot\src\commands\Invoke-UPrintSetup.ps1"
        $result = Invoke-UPrintSetup -PrinterName $Printer -Json:$useJson
        Write-Output $result
        if ($useJson) {
            $jsonResult = $result | ConvertFrom-Json
            if (-not $jsonResult.success) {
                if ($jsonResult.error.code -eq 'INVALID_ARGUMENT') { exit 3 }
                exit 1
            }
        }
    }
    'printers' {
        $unexpected = @($SubCommand) + @($Args) |
            Where-Object { $_ -and $_ -notin @('--universal-only', '-u') } |
            Select-Object -First 1
        if ($unexpected) {
            $message = if ($unexpected -match '^-') {
                "Unknown option: $unexpected"
            } else {
                "Unexpected argument: $unexpected"
            }
            if ($useJson) {
                $err = New-UPrintError -Code 'INVALID_ARGUMENT' -Message $message -Suggestion "Run 'uprint --help' for usage"
                Format-UPrintOutput -Command 'printers' -ErrorResult $err -Json
            } else {
                [Console]::Error.WriteLine("$message. Run 'uprint --help' for usage.")
            }
            exit 3
        }
        . "$scriptRoot\src\commands\Get-UPrintPrinters.ps1"
        $params = @{ Json = $useJson }
        if ($SubCommand -in @('--universal-only', '-u') -or
            $Args -contains '--universal-only' -or
            $Args -contains '-u') {
            $params.UniversalOnly = $true
        }
        $result = Get-UPrintPrinters @params
        Write-Output $result
        if ($useJson -and -not ($result | ConvertFrom-Json).success) {
            exit 1
        }
    }
    'status' {
        $unexpected = @($SubCommand) + @($Args) | Where-Object { $_ } | Select-Object -First 1
        if ($unexpected) {
            $message = if ($unexpected -match '^-') {
                "Unknown option: $unexpected"
            } else {
                "Unexpected argument: $unexpected"
            }
            if ($useJson) {
                $err = New-UPrintError -Code 'INVALID_ARGUMENT' -Message $message -Suggestion "Run 'uprint --help' for usage"
                Format-UPrintOutput -Command 'status' -ErrorResult $err -Json
            } else {
                [Console]::Error.WriteLine("$message. Run 'uprint --help' for usage.")
            }
            exit 3
        }
        . "$scriptRoot\src\commands\Get-UPrintStatus.ps1"
        $result = Get-UPrintStatus -PrinterName $printerName -Json:$useJson
        Write-Output $result
        if ($useJson -and -not ($result | ConvertFrom-Json).success) {
            exit 1
        }
    }
    'print' {
        . "$scriptRoot\src\commands\Invoke-UPrintPrint.ps1"
        if (-not $SubCommand) {
            $message = 'print requires a file path'
            $suggestion = "Use 'uprint print <file>'"
            if ($useJson) {
                $err = New-UPrintError -Code 'INVALID_ARGUMENT' -Message $message -Suggestion $suggestion
                Format-UPrintOutput -Command 'print' -ErrorResult $err -Json
            } else {
                [Console]::Error.WriteLine("$message. $suggestion.")
            }
            exit 3
        }
        $params = @{ FilePath = $SubCommand; PrinterName = $printerName; Json = $useJson }
        # Parse optional flags from remaining args
        if ($Args) {
            $knownPrintOptions = @('--copies', '--duplex', '--color', '--mono')
            $unknownOption = $Args |
                Where-Object { $_ -match '^-' -and $_ -notin $knownPrintOptions } |
                Select-Object -First 1
            if ($unknownOption) {
                $message = "Unknown option: $unknownOption"
                if ($useJson) {
                    $err = New-UPrintError -Code 'INVALID_ARGUMENT' -Message $message -Suggestion "Run 'uprint --help' for usage"
                    Format-UPrintOutput -Command 'print' -ErrorResult $err -Json
                } else {
                    [Console]::Error.WriteLine("$message. Run 'uprint --help' for usage.")
                }
                exit 3
            }
            $unexpectedArgument = $null
            for ($index = 0; $index -lt $Args.Count; $index++) {
                if ($Args[$index] -eq '--copies') {
                    $index++
                    continue
                }
                if ($Args[$index] -notin @('--duplex', '--color', '--mono')) {
                    $unexpectedArgument = $Args[$index]
                    break
                }
            }
            if ($unexpectedArgument) {
                $message = "Unexpected argument: $unexpectedArgument"
                if ($useJson) {
                    $err = New-UPrintError -Code 'INVALID_ARGUMENT' -Message $message -Suggestion "Run 'uprint --help' for usage"
                    Format-UPrintOutput -Command 'print' -ErrorResult $err -Json
                } else {
                    [Console]::Error.WriteLine("$message. Run 'uprint --help' for usage.")
                }
                exit 3
            }
            if ($Args -contains '--mono' -and $Args -contains '--color') {
                $message = '--color and --mono are mutually exclusive'
                $suggestion = 'Use only one color-mode option'
                if ($useJson) {
                    $err = New-UPrintError -Code 'INVALID_ARGUMENT' -Message $message -Suggestion $suggestion
                    Format-UPrintOutput -Command 'print' -ErrorResult $err -Json
                } else {
                    [Console]::Error.WriteLine("$message. $suggestion.")
                }
                exit 3
            }
            if ($Args -contains '--duplex') { $params.Duplex = $true }
            if ($Args -contains '--mono') { $params.ColorMode = 'Mono' }
            if ($Args -contains '--color') { $params.ColorMode = 'Color' }
            $copiesIdx = [array]::IndexOf($Args, '--copies')
            if ($copiesIdx -ge 0) {
                $copiesValue = if ($copiesIdx -lt ($Args.Count - 1)) { $Args[$copiesIdx + 1] } else { $null }
                if ($copiesValue -notmatch '^[1-9]\d*$') {
                    $message = '--copies requires a positive integer'
                    $suggestion = "Use '--copies <count>' with a value of 1 or more"
                    if ($useJson) {
                        $err = New-UPrintError -Code 'INVALID_ARGUMENT' -Message $message -Suggestion $suggestion
                        Format-UPrintOutput -Command 'print' -ErrorResult $err -Json
                    } else {
                        [Console]::Error.WriteLine("$message. $suggestion.")
                    }
                    exit 3
                }
                $params.Copies = [int]$copiesValue
            }
        }
        $result = Invoke-UPrintPrint @params
        Write-Output $result
        if ($useJson) {
            $jsonResult = $result | ConvertFrom-Json
            if (-not $jsonResult.success) {
                if ($jsonResult.error.code -eq 'FILE_NOT_FOUND') { exit 3 }
                exit 1
            }
        }
    }
    'queue' {
        . "$scriptRoot\src\commands\Get-UPrintQueue.ps1"
        if ($SubCommand -and $SubCommand -ne 'cancel') {
            $message = "Unknown queue subcommand: $SubCommand"
            $suggestion = "Use 'uprint queue' or 'uprint queue cancel'"
            if ($useJson) {
                $err = New-UPrintError -Code 'INVALID_ARGUMENT' -Message $message -Suggestion $suggestion
                Format-UPrintOutput -Command 'queue' -ErrorResult $err -Json
            } else {
                [Console]::Error.WriteLine("$message. $suggestion.")
            }
            exit 3
        }
        if ($SubCommand -eq 'cancel') {
            $cancelAll = $Args -contains '--all'
            $jobId = ($Args | Where-Object { $_ -match '^\d+$' } | Select-Object -First 1)
            if ($jobId -and $jobId -notmatch '^[1-9]\d*$') {
                $message = 'Print job ID must be a positive integer'
                $suggestion = "Use 'uprint queue cancel <job-id>' with a value of 1 or more"
                if ($useJson) {
                    $err = New-UPrintError -Code 'INVALID_ARGUMENT' -Message $message -Suggestion $suggestion
                    Format-UPrintOutput -Command 'queue' -ErrorResult $err -Json
                } else {
                    [Console]::Error.WriteLine("$message. $suggestion.")
                }
                exit 3
            }
            if ($cancelAll -and $jobId) {
                $message = 'A job ID and --all are mutually exclusive'
                $suggestion = 'Use one cancellation selector'
                if ($useJson) {
                    $err = New-UPrintError -Code 'INVALID_ARGUMENT' -Message $message -Suggestion $suggestion
                    Format-UPrintOutput -Command 'queue' -ErrorResult $err -Json
                } else {
                    [Console]::Error.WriteLine("$message. $suggestion.")
                }
                exit 3
            }
            if (-not $cancelAll -and -not $jobId) {
                $message = 'queue cancel requires a job ID or --all'
                $suggestion = "Use 'uprint queue cancel <job-id>' or 'uprint queue cancel --all'"
                if ($useJson) {
                    $err = New-UPrintError -Code 'INVALID_ARGUMENT' -Message $message -Suggestion $suggestion
                    Format-UPrintOutput -Command 'queue' -ErrorResult $err -Json
                } else {
                    [Console]::Error.WriteLine("$message. $suggestion.")
                }
                exit 3
            }
            $selector = if ($cancelAll) { '--all' } else { [string]$jobId }
            $unexpectedCancelArgument = $Args |
                Where-Object { $_ -ne $selector } |
                Select-Object -First 1
            if ($unexpectedCancelArgument) {
                $message = "Unexpected queue cancellation argument: $unexpectedCancelArgument"
                $suggestion = 'Use one job ID or --all'
                if ($useJson) {
                    $err = New-UPrintError -Code 'INVALID_ARGUMENT' -Message $message -Suggestion $suggestion
                    Format-UPrintOutput -Command 'queue' -ErrorResult $err -Json
                } else {
                    [Console]::Error.WriteLine("$message. $suggestion.")
                }
                exit 3
            }
            $params = @{ PrinterName = $printerName; Cancel = $true; Json = $useJson }
            if ($cancelAll) { $params.CancelAll = $true }
            elseif ($jobId) { $params.JobId = [int]$jobId }
            $result = Get-UPrintQueue @params
        } else {
            $result = Get-UPrintQueue -PrinterName $printerName -Json:$useJson
        }
        Write-Output $result
        if ($useJson -and -not ($result | ConvertFrom-Json).success) {
            exit 1
        }
    }
    'health' {
        $unexpected = @($SubCommand) + @($Args) | Where-Object { $_ } | Select-Object -First 1
        if ($unexpected) {
            $message = if ($unexpected -match '^-') {
                "Unknown option: $unexpected"
            } else {
                "Unexpected argument: $unexpected"
            }
            if ($useJson) {
                $err = New-UPrintError -Code 'INVALID_ARGUMENT' -Message $message -Suggestion "Run 'uprint --help' for usage"
                Format-UPrintOutput -Command 'health' -ErrorResult $err -Json
            } else {
                [Console]::Error.WriteLine("$message. Run 'uprint --help' for usage.")
            }
            exit 3
        }
        . "$scriptRoot\src\commands\Get-UPrintHealth.ps1"
        Get-UPrintHealth -PrinterName $printerName -Json:$useJson
    }
    'config' {
        if ($SubCommand -and $SubCommand -notin @('get', 'set')) {
            $message = "Unknown config subcommand: $SubCommand"
            $suggestion = "Use 'uprint config get' or 'uprint config set'"
            if ($useJson) {
                $err = New-UPrintError -Code 'INVALID_ARGUMENT' -Message $message -Suggestion $suggestion
                Format-UPrintOutput -Command 'config' -ErrorResult $err -Json
            } else {
                [Console]::Error.WriteLine("$message. $suggestion.")
            }
            exit 3
        }
        if ($SubCommand -eq 'set' -and $Args.Count -ne 2) {
            $message = 'config set requires a key and value'
            $suggestion = "Use 'uprint config set <key> <value>'"
            if ($useJson) {
                $err = New-UPrintError -Code 'INVALID_ARGUMENT' -Message $message -Suggestion $suggestion
                Format-UPrintOutput -Command 'config' -ErrorResult $err -Json
            } else {
                [Console]::Error.WriteLine("$message. $suggestion.")
            }
            exit 3
        }
        if ($SubCommand -eq 'get' -and $Args.Count -gt 0) {
            $message = 'config get does not accept a key'
            $suggestion = "Use 'uprint config get'"
            if ($useJson) {
                $err = New-UPrintError -Code 'INVALID_ARGUMENT' -Message $message -Suggestion $suggestion
                Format-UPrintOutput -Command 'config' -ErrorResult $err -Json
            } else {
                [Console]::Error.WriteLine("$message. $suggestion.")
            }
            exit 3
        }
        if ($SubCommand -eq 'set') {
            $configKeys = @('defaultPrinter', 'autoWake', 'timeout', 'jsonOutput')
            if ($Args[0] -notin $configKeys) {
                $message = "Unknown configuration key: $($Args[0])"
                $suggestion = 'Use defaultPrinter, autoWake, timeout, or jsonOutput'
                if ($useJson) {
                    $err = New-UPrintError -Code 'INVALID_ARGUMENT' -Message $message -Suggestion $suggestion
                    Format-UPrintOutput -Command 'config' -ErrorResult $err -Json
                } else {
                    [Console]::Error.WriteLine("$message. $suggestion.")
                }
                exit 3
            }
            if ($Args[0] -eq 'timeout' -and $Args[1] -notmatch '^\d+$') {
                $message = "Invalid value for timeout: $($Args[1])"
                $suggestion = 'Use a nonnegative integer'
                if ($useJson) {
                    $err = New-UPrintError -Code 'INVALID_ARGUMENT' -Message $message -Suggestion $suggestion
                    Format-UPrintOutput -Command 'config' -ErrorResult $err -Json
                } else {
                    [Console]::Error.WriteLine("$message. $suggestion.")
                }
                exit 3
            }
            if ($Args[0] -in @('autoWake', 'jsonOutput') -and $Args[1] -notin @('true', 'false')) {
                $message = "Invalid value for $($Args[0]): $($Args[1])"
                $suggestion = 'Use true or false'
                if ($useJson) {
                    $err = New-UPrintError -Code 'INVALID_ARGUMENT' -Message $message -Suggestion $suggestion
                    Format-UPrintOutput -Command 'config' -ErrorResult $err -Json
                } else {
                    [Console]::Error.WriteLine("$message. $suggestion.")
                }
                exit 3
            }
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
        [Console]::Error.WriteLine("Unknown command: $Command. Run 'uprint --help' for usage.")
        exit 3
    }
}
