function Get-UPrintStatus {
    [CmdletBinding()]
    param(
        [string]$PrinterName,
        [switch]$Json
    )

    try {
        $printer = Get-Printer -Name $PrinterName -ErrorAction Stop
        $jobs = @(Get-PrintJob -PrinterName $PrinterName -ErrorAction SilentlyContinue)

        $data = @{
            name        = $printer.Name
            status      = $printer.PrinterStatus.ToString()
            driver      = $printer.DriverName
            port        = $printer.PortName
            type        = $printer.Type.ToString()
            shared      = $printer.Shared
            pendingJobs = $jobs.Count
            isUP        = ($printer.DriverName -match 'Universal Print')
        }

        $warnings = @()
        if ($jobs.Count -gt 5) { $warnings += "High job count: $($jobs.Count) pending" }

        if ($Json) {
            return Format-UPrintOutput -Command 'status' -Data $data -Warnings $warnings -Json
        }

        # Human output
        $upTag = if ($data.isUP) { ' [Universal Print]' } else { '' }
        $lines = @(
            "$($data.name)$upTag — $($data.status)",
            "",
            "  Driver:       $($data.driver)",
            "  Port:         $($data.port)",
            "  Pending Jobs: $($data.pendingJobs)"
        )
        if ($warnings) { $lines += ""; $lines += "  ⚠ $($warnings -join '; ')" }
        return ($lines -join "`n")
    }
    catch {
        $err = New-UPrintError -Known 'PRINTER_NOT_FOUND'
        if ($Json) {
            return Format-UPrintOutput -Command 'status' -ErrorResult $err -Json
        }
        Write-Error "Printer '$PrinterName' not found. Run 'uprint printers' to list available printers."
    }
}
