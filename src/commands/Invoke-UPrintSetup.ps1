function Invoke-UPrintSetup {
    [CmdletBinding()]
    param(
        [string]$PrinterName,
        [switch]$Json
    )

    # Discover printers
    $printers = @(Get-Printer | Where-Object { $_.Name -notmatch '\(redirected' })

    if ($printers.Count -eq 0) {
        $err = New-UPrintError -Code 'NO_PRINTERS' -Message 'No printers found on this system' -Suggestion 'Add a printer in Windows Settings first'
        if ($Json) { return Format-UPrintOutput -Command 'setup' -ErrorResult $err -Json }
        Write-Error "No printers found. Add a printer in Windows Settings first."
        return
    }

    if ($Json) {
        if (-not $PrinterName) {
            $err = New-UPrintError -Code 'INVALID_ARGUMENT' -Message 'setup requires --printer in JSON mode' -Suggestion "Use 'uprint setup --printer <name> --json'"
            return Format-UPrintOutput -Command 'setup' -ErrorResult $err -Json
        }

        $selected = $printers | Where-Object Name -eq $PrinterName | Select-Object -First 1
        if (-not $selected) {
            $err = New-UPrintError -Known 'PRINTER_NOT_FOUND'
            return Format-UPrintOutput -Command 'setup' -ErrorResult $err -Json
        }

        $config = Set-UPrintConfig -Key 'defaultPrinter' -Value $selected.Name
        $data = @{
            defaultPrinter = $selected.Name
            driver         = $selected.DriverName
            isUP           = ($selected.DriverName -match 'Universal Print')
            config         = $config
        }
        return Format-UPrintOutput -Command 'setup' -Data $data -Json
    }

    Write-Host "uprint setup — Printer Discovery" -ForegroundColor Cyan
    Write-Host ""

    # Display printers with numbers
    Write-Host "Available printers:" -ForegroundColor Yellow
    Write-Host ""
    for ($i = 0; $i -lt $printers.Count; $i++) {
        $p = $printers[$i]
        $upTag = if ($p.DriverName -match 'Universal Print') { ' [Universal Print]' } else { '' }
        $statusTag = if ($p.PrinterStatus -eq 'Normal') { '' } else { " ($($p.PrinterStatus))" }
        Write-Host "  [$($i + 1)] $($p.Name)$upTag$statusTag"
    }

    Write-Host ""
    $choice = Read-Host "Select default printer (1-$($printers.Count))"

    if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $printers.Count) {
        $selected = $printers[[int]$choice - 1]
        $config = Set-UPrintConfig -Key 'defaultPrinter' -Value $selected.Name

        $data = @{
            defaultPrinter = $selected.Name
            driver         = $selected.DriverName
            isUP           = ($selected.DriverName -match 'Universal Print')
            config         = $config
        }

        Write-Host ""
        Write-Host "Default printer set to: $($selected.Name)" -ForegroundColor Green
        if ($selected.DriverName -match 'Universal Print') {
            Write-Host "This is a Universal Print printer — jobs will be held in cloud until badge release." -ForegroundColor Yellow
        }
        Write-Host "Config saved to: $($env:USERPROFILE)\.uprint\config.json"
    }
    else {
        Write-Host "Invalid selection. Run 'uprint setup' again." -ForegroundColor Red
    }
}
