BeforeAll {
    . "$PSScriptRoot/../src/lib/New-UPrintError.ps1"
}

Describe 'New-UPrintError' {
    It 'creates a structured error with code, message, suggestion' {
        $err = New-UPrintError -Code 'PRINTER_OFFLINE' -Message 'Printer not responding' -Suggestion "Check network"
        $err.code | Should -Be 'PRINTER_OFFLINE'
        $err.message | Should -Be 'Printer not responding'
        $err.suggestion | Should -Be 'Check network'
    }

    It 'works without suggestion' {
        $err = New-UPrintError -Code 'UNKNOWN' -Message 'Something broke'
        $err.code | Should -Be 'UNKNOWN'
        $err.suggestion | Should -BeNullOrEmpty
    }

    It 'returns known error for PRINTER_OFFLINE shortcut' {
        $err = New-UPrintError -Known 'PRINTER_OFFLINE'
        $err.code | Should -Be 'PRINTER_OFFLINE'
        $err.message | Should -Not -BeNullOrEmpty
        $err.suggestion | Should -Not -BeNullOrEmpty
    }
}
