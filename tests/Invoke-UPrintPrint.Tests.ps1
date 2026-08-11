BeforeAll {
    . "$PSScriptRoot/Test-WindowsCommandStubs.ps1"
    . "$PSScriptRoot/../src/lib/Format-UPrintOutput.ps1"
    . "$PSScriptRoot/../src/lib/New-UPrintError.ps1"
    . "$PSScriptRoot/../src/commands/Invoke-UPrintPrint.ps1"
}

Describe 'Invoke-UPrintPrint' {
    Context 'when file exists and printer is available (SumatraPDF tier)' {
        BeforeAll {
            Mock Test-Path { $true }
            Mock Resolve-Path { [PSCustomObject]@{ Path = 'C:\test\report.pdf' } }
            Mock Get-Printer { [PSCustomObject]@{ Name = 'Office-Printer-2'; PrinterStatus = 'Normal'; DriverName = 'Universal Print Class Driver' } } -ParameterFilter { $Name -eq 'Office-Printer-2' }
            Mock Start-Process { } -Verifiable
        }

        It 'prints the file and returns success JSON with engine and UP warning' {
            $result = Invoke-UPrintPrint -FilePath 'C:\test\report.pdf' -PrinterName 'Office-Printer-2' -Json | ConvertFrom-Json
            $result.success | Should -Be $true
            $result.data.printer | Should -Be 'Office-Printer-2'
            $result.data.status | Should -Be 'submitted_to_cloud'
            $result.data.engine | Should -Not -BeNullOrEmpty
            $result.warnings | Should -Not -BeNullOrEmpty
        }
    }

    Context 'when file does not exist' {
        BeforeAll {
            Mock Test-Path { $false } -ParameterFilter { $Path -eq 'C:\missing.pdf' }
        }

        It 'returns FILE_NOT_FOUND error' {
            $result = Invoke-UPrintPrint -FilePath 'C:\missing.pdf' -Json | ConvertFrom-Json
            $result.success | Should -Be $false
            $result.error.code | Should -Be 'FILE_NOT_FOUND'
        }
    }

    Context 'when non-UP printer is used' {
        BeforeAll {
            Mock Test-Path { $true }
            Mock Resolve-Path { [PSCustomObject]@{ Path = 'C:\test\doc.txt' } }
            Mock Get-Printer { [PSCustomObject]@{ Name = 'LocalPrinter'; PrinterStatus = 'Normal'; DriverName = 'HP LaserJet' } } -ParameterFilter { $Name -eq 'LocalPrinter' }
            Mock Start-Process { }
        }

        It 'returns submitted status without UP warning' {
            $result = Invoke-UPrintPrint -FilePath 'C:\test\doc.txt' -PrinterName 'LocalPrinter' -Json | ConvertFrom-Json
            $result.data.status | Should -Be 'submitted'
            $result.warnings.Count | Should -Be 0
        }
    }
}
