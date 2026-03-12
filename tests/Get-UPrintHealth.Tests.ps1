BeforeAll {
    . "$PSScriptRoot/../src/lib/Format-UPrintOutput.ps1"
    . "$PSScriptRoot/../src/lib/New-UPrintError.ps1"
    . "$PSScriptRoot/../src/commands/Get-UPrintHealth.ps1"
}

Describe 'Get-UPrintHealth' {
    Context 'when everything is healthy' {
        BeforeAll {
            Mock Get-Printer {
                [PSCustomObject]@{ Name = 'Office-Printer-1'; PrinterStatus = 'Normal'; DriverName = 'Universal Print Class Driver' }
            } -ParameterFilter { $Name -eq 'Office-Printer-1' }
            Mock Get-PrintJob { @() } -ParameterFilter { $PrinterName -eq 'Office-Printer-1' }
            Mock Get-Service { [PSCustomObject]@{ Status = 'Running' } } -ParameterFilter { $Name -eq 'Spooler' }
        }

        It 'returns healthy status in JSON' {
            $result = Get-UPrintHealth -PrinterName 'Office-Printer-1' -Json | ConvertFrom-Json
            $result.success | Should -Be $true
            $result.data.healthy | Should -Be $true
            $result.data.checks | Should -Not -BeNullOrEmpty
        }

        It 'shows PASS for all checks in human mode' {
            $result = Get-UPrintHealth -PrinterName 'Office-Printer-1'
            $result | Should -Match 'PASS'
        }
    }

    Context 'when spooler is stopped' {
        BeforeAll {
            Mock Get-Printer {
                [PSCustomObject]@{ Name = 'Office-Printer-1'; PrinterStatus = 'Normal'; DriverName = 'Universal Print Class Driver' }
            } -ParameterFilter { $Name -eq 'Office-Printer-1' }
            Mock Get-PrintJob { @() }
            Mock Get-Service { [PSCustomObject]@{ Status = 'Stopped' } } -ParameterFilter { $Name -eq 'Spooler' }
        }

        It 'returns unhealthy with spooler warning' {
            $result = Get-UPrintHealth -PrinterName 'Office-Printer-1' -Json | ConvertFrom-Json
            $result.data.healthy | Should -Be $false
        }
    }
}
