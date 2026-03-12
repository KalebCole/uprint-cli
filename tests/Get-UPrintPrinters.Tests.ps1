BeforeAll {
    . "$PSScriptRoot/../src/lib/Format-UPrintOutput.ps1"
    . "$PSScriptRoot/../src/lib/New-UPrintError.ps1"
    . "$PSScriptRoot/../src/commands/Get-UPrintPrinters.ps1"
}

Describe 'Get-UPrintPrinters' {
    Context 'when printers are available (Windows native)' {
        BeforeAll {
            Mock Get-Printer {
                return @(
                    [PSCustomObject]@{ Name = 'Office-Printer-1'; Type = 'Local'; DriverName = 'Universal Print Class Driver'; PrinterStatus = 'Normal' },
                    [PSCustomObject]@{ Name = 'Office-Printer-2'; Type = 'Local'; DriverName = 'Universal Print Class Driver'; PrinterStatus = 'Normal' },
                    [PSCustomObject]@{ Name = 'Microsoft Print to PDF'; Type = 'Local'; DriverName = 'Microsoft Print To PDF'; PrinterStatus = 'Normal' }
                )
            }
        }

        It 'returns all printers in JSON mode' {
            $result = Get-UPrintPrinters -Json | ConvertFrom-Json
            $result.success | Should -Be $true
            $result.data.printers.Count | Should -Be 3
        }

        It 'filters to Universal Print printers with -UniversalOnly' {
            $result = Get-UPrintPrinters -UniversalOnly -Json | ConvertFrom-Json
            $result.data.printers.Count | Should -Be 2
            $result.data.printers[0].name | Should -Be 'Office-Printer-1'
        }

        It 'returns human-readable output by default' {
            $result = Get-UPrintPrinters
            $result | Should -Match 'Office-Printer-1'
        }
    }

    Context 'when no printers found' {
        BeforeAll {
            Mock Get-Printer { return @() }
        }

        It 'returns empty list with success=true' {
            $result = Get-UPrintPrinters -Json | ConvertFrom-Json
            $result.success | Should -Be $true
            $result.data.printers.Count | Should -Be 0
        }
    }
}
