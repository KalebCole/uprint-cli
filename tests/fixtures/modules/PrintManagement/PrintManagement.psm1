function Get-Printer {
    [CmdletBinding()]
    param([string]$Name)

    if ($env:UPRINT_TEST_SCENARIO -eq 'list-error') {
        throw 'Fixture printer-list failure'
    }

    $printers = @(
        [PSCustomObject]@{
            Name          = 'Office UP'
            Type          = 'Local'
            DriverName    = 'Universal Print Class Driver'
            PrinterStatus = 'Normal'
            PortName      = 'PORT-UP'
            Shared        = $false
        },
        [PSCustomObject]@{
            Name          = 'Local Printer'
            Type          = 'Local'
            DriverName    = 'Contoso Laser'
            PrinterStatus = 'Normal'
            PortName      = 'PORT-LOCAL'
            Shared        = $true
        }
    )

    if ($env:UPRINT_TEST_SCENARIO -eq 'no-printers') {
        return
    }

    if ($Name) {
        $printer = $printers | Where-Object Name -eq $Name
        if (-not $printer) {
            throw "Printer '$Name' was not found"
        }
        return $printer
    }

    return $printers
}

function Get-PrintJob {
    [CmdletBinding()]
    param([string]$PrinterName)

    if ($env:UPRINT_TEST_SCENARIO -eq 'queue-error') {
        throw 'Fixture queue failure'
    }

    if ($env:UPRINT_TEST_SCENARIO -eq 'queue-empty') {
        return
    }

    if ($env:UPRINT_TEST_SCENARIO -eq 'high-job-count') {
        return 1..6 | ForEach-Object {
            [PSCustomObject]@{
                Id            = $_
                DocumentName  = "document-$_.pdf"
                JobStatus     = 'Spooling'
                UserName      = 'fixture-user'
                SubmittedTime = [datetime]'2026-01-02T03:04:05Z'
            }
        }
    }

    return @(
        [PSCustomObject]@{
            Id            = 7
            DocumentName  = 'report.pdf'
            JobStatus     = 'Spooling'
            UserName      = 'fixture-user'
            SubmittedTime = [datetime]'2026-01-02T03:04:05Z'
        }
    )
}

function Remove-PrintJob {
    [CmdletBinding()]
    param(
        [object]$PrinterObject,
        [string]$PrinterName,
        [int]$ID
    )

    if ($env:UPRINT_TEST_SCENARIO -eq 'queue-error') {
        throw 'Fixture queue failure'
    }
}

function Get-Service {
    [CmdletBinding()]
    param([string]$Name)

    $status = if ($env:UPRINT_TEST_SCENARIO -eq 'spooler-stopped') {
        'Stopped'
    } else {
        'Running'
    }
    return [PSCustomObject]@{ Status = $status }
}
