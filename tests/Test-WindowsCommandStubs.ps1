if (-not (Get-Command Get-Printer -ErrorAction SilentlyContinue)) {
    function global:Get-Printer {
        [CmdletBinding()]
        param([string]$Name)

        throw 'Get-Printer is available only through Windows PrintManagement.'
    }
}

if (-not (Get-Command Get-PrintJob -ErrorAction SilentlyContinue)) {
    function global:Get-PrintJob {
        [CmdletBinding()]
        param([string]$PrinterName)

        throw 'Get-PrintJob is available only through Windows PrintManagement.'
    }
}

if (-not (Get-Command Remove-PrintJob -ErrorAction SilentlyContinue)) {
    function global:Remove-PrintJob {
        [CmdletBinding()]
        param(
            [object]$PrinterObject,
            [string]$PrinterName,
            [int]$ID
        )

        throw 'Remove-PrintJob is available only through Windows PrintManagement.'
    }
}

if (-not (Get-Command Get-Service -ErrorAction SilentlyContinue)) {
    function global:Get-Service {
        [CmdletBinding()]
        param([string]$Name)

        throw 'Get-Service is not available in this test environment.'
    }
}
