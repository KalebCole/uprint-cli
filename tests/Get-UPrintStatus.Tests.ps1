BeforeAll {
    . "$PSScriptRoot/Test-WindowsCommandStubs.ps1"
    . "$PSScriptRoot/../src/lib/Format-UPrintOutput.ps1"
    . "$PSScriptRoot/../src/lib/New-UPrintError.ps1"
    . "$PSScriptRoot/../src/commands/Get-UPrintStatus.ps1"
}

Describe 'Get-UPrintStatus' {
    Context 'when printer exists' {
        BeforeAll {
            Mock Get-Printer {
                [PSCustomObject]@{
                    Name           = 'Office-Printer-1'
                    PrinterStatus  = 'Normal'
                    DriverName     = 'Universal Print Class Driver'
                    PortName       = 'IPP-8a73682b'
                    Shared         = $false
                    Type           = 'Local'
                }
            } -ParameterFilter { $Name -eq 'Office-Printer-1' }

            Mock Get-PrintJob { return @() } -ParameterFilter { $PrinterName -eq 'Office-Printer-1' }
        }

        It 'returns status in JSON mode' {
            $result = Get-UPrintStatus -PrinterName 'Office-Printer-1' -Json | ConvertFrom-Json
            $result.success | Should -Be $true
            $result.data.name | Should -Be 'Office-Printer-1'
            $result.data.status | Should -Be 'Normal'
            $result.data.pendingJobs | Should -Be 0
        }

        It 'returns human-readable status by default' {
            $result = Get-UPrintStatus -PrinterName 'Office-Printer-1'
            $result | Should -Match 'Office-Printer-1'
            $result | Should -Match 'Normal'
        }
    }

    Context 'when printer not found' {
        BeforeAll {
            Mock Get-Printer { throw "Printer 'FakePrinter' not found" } -ParameterFilter { $Name -eq 'FakePrinter' }
        }

        It 'returns error in JSON mode' {
            $result = Get-UPrintStatus -PrinterName 'FakePrinter' -Json | ConvertFrom-Json
            $result.success | Should -Be $false
            $result.error.code | Should -Be 'PRINTER_NOT_FOUND'
        }
    }
}
