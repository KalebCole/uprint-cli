function Get-UPrintHealth {
    [CmdletBinding()]
    param(
        [string]$PrinterName,
        [switch]$Json
    )

    $checks = @()
    $healthy = $true

    # Check 1: Print Spooler service
    try {
        $spooler = Get-Service -Name 'Spooler' -ErrorAction Stop
        $spoolerOk = $spooler.Status -eq 'Running'
        $checks += @{ name = 'Print Spooler'; status = if ($spoolerOk) { 'PASS' } else { 'FAIL' }; detail = $spooler.Status.ToString() }
        if (-not $spoolerOk) { $healthy = $false }
    } catch {
        $checks += @{ name = 'Print Spooler'; status = 'FAIL'; detail = 'Service not found' }
        $healthy = $false
    }

    # Check 2: Printer exists and is responding
    try {
        $printer = Get-Printer -Name $PrinterName -ErrorAction Stop
        $printerOk = $printer.PrinterStatus -eq 'Normal'
        $checks += @{ name = 'Printer Status'; status = if ($printerOk) { 'PASS' } else { 'WARN' }; detail = $printer.PrinterStatus.ToString() }
        if (-not $printerOk) { $healthy = $false }
    } catch {
        $checks += @{ name = 'Printer Status'; status = 'FAIL'; detail = "Printer '$PrinterName' not found" }
        $healthy = $false
    }

    # Check 3: Queue backlog
    try {
        $jobs = @(Get-PrintJob -PrinterName $PrinterName -ErrorAction SilentlyContinue)
        $queueOk = $jobs.Count -le 10
        $checks += @{ name = 'Queue Backlog'; status = if ($queueOk) { 'PASS' } else { 'WARN' }; detail = "$($jobs.Count) jobs" }
        if (-not $queueOk) { $healthy = $false }
    } catch {
        $checks += @{ name = 'Queue Backlog'; status = 'WARN'; detail = 'Could not read queue' }
    }

    # Check 4: Universal Print driver
    try {
        if ($printer -and ($printer.DriverName -match 'Universal Print')) {
            $checks += @{ name = 'Universal Print'; status = 'PASS'; detail = 'UP driver detected' }
        } else {
            $checks += @{ name = 'Universal Print'; status = 'INFO'; detail = 'Not a UP printer' }
        }
    } catch {
        $checks += @{ name = 'Universal Print'; status = 'SKIP'; detail = 'Printer not available' }
    }

    $data = @{
        printer = $PrinterName
        healthy = $healthy
        checks  = $checks
    }

    $warnings = @()
    $failedChecks = $checks | Where-Object { $_.status -in @('FAIL', 'WARN') }
    foreach ($fc in $failedChecks) {
        $warnings += "$($fc.name): $($fc.detail)"
    }

    if ($Json) {
        return Format-UPrintOutput -Command 'health' -Data $data -Warnings $warnings -Json
    }

    $icon = if ($healthy) { '✅' } else { '❌' }
    $lines = @("$icon Health Check — $PrinterName", "")
    foreach ($c in $checks) {
        $statusIcon = switch ($c.status) { 'PASS' { '✅' }; 'FAIL' { '❌' }; 'WARN' { '⚠️' }; default { 'ℹ️' } }
        $lines += "  $statusIcon [$($c.status)] $($c.name): $($c.detail)"
    }
    return ($lines -join "`n")
}
