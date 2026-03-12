function Get-UPrintPrinters {
    [CmdletBinding()]
    param(
        [switch]$UniversalOnly,
        [switch]$Json
    )

    try {
        $printers = Get-Printer | ForEach-Object {
            @{
                name       = $_.Name
                type       = $_.Type.ToString()
                driver     = $_.DriverName
                status     = $_.PrinterStatus.ToString()
                isUP       = ($_.DriverName -match 'Universal Print')
            }
        }

        if ($UniversalOnly) {
            $printers = $printers | Where-Object { $_.isUP }
        }

        # Filter out RDP redirected duplicates
        $printers = $printers | Where-Object { $_.name -notmatch '\(redirected' }

        $data = @{ printers = @($printers); count = @($printers).Count }

        if ($Json) {
            return Format-UPrintOutput -Command 'printers' -Data $data -Json
        }

        # Human output
        $lines = @("Universal Print Printers:", "")
        foreach ($p in $printers) {
            $upTag = if ($p.isUP) { ' [UP]' } else { '' }
            $lines += "  $($p.name)$upTag — $($p.status) ($($p.driver))"
        }
        $lines += ""
        $lines += "Total: $(@($printers).Count) printer(s)"
        return ($lines -join "`n")
    }
    catch {
        $err = New-UPrintError -Code 'LIST_FAILED' -Message $_.Exception.Message -Suggestion 'Check print spooler service'
        if ($Json) {
            return Format-UPrintOutput -Command 'printers' -ErrorResult $err -Json
        }
        Write-Error $_.Exception.Message
    }
}
