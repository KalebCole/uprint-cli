BeforeAll {
    . "$PSScriptRoot/../src/lib/Format-UPrintOutput.ps1"
}

Describe 'Format-UPrintOutput' {
    Context 'JSON mode' {
        It 'produces a versioned envelope with success=true' {
            $result = Format-UPrintOutput -Command 'printers' -Data @{ count = 2 } -Json
            $parsed = $result | ConvertFrom-Json
            $parsed.version | Should -Be 1
            $parsed.command | Should -Be 'printers'
            $parsed.success | Should -Be $true
            $parsed.data.count | Should -Be 2
            $parsed.timestamp | Should -Not -BeNullOrEmpty
        }

        It 'produces error envelope when -ErrorResult is passed' {
            $err = @{ code = 'PRINTER_OFFLINE'; message = 'Printer not responding'; suggestion = "Run 'uprint health'" }
            $result = Format-UPrintOutput -Command 'print' -ErrorResult $err -Json
            $parsed = $result | ConvertFrom-Json
            $parsed.success | Should -Be $false
            $parsed.error.code | Should -Be 'PRINTER_OFFLINE'
        }

        It 'includes warnings when provided' {
            $result = Format-UPrintOutput -Command 'status' -Data @{} -Warnings @('Low toner') -Json
            $parsed = $result | ConvertFrom-Json
            $parsed.warnings | Should -Contain 'Low toner'
        }
    }

    Context 'Human mode (default)' {
        It 'returns data as formatted string when no -Json flag' {
            $result = Format-UPrintOutput -Command 'printers' -Data @{ name = 'Office-Printer-1' } -HumanMessage 'Printer: Office-Printer-1'
            $result | Should -Be 'Printer: Office-Printer-1'
        }

        It 'falls back to JSON-serialized data when no HumanMessage provided' {
            $result = Format-UPrintOutput -Command 'printers' -Data @{ name = 'Office-Printer-1' }
            $result | Should -Match 'Office-Printer-1'
        }
    }
}
