BeforeAll {
    . "$PSScriptRoot/../src/lib/Format-UPrintOutput.ps1"
    . "$PSScriptRoot/../src/lib/New-UPrintError.ps1"
    . "$PSScriptRoot/../src/commands/Get-UPrintQueue.ps1"
}

Describe 'Get-UPrintQueue' {
    Context 'list action' {
        BeforeAll {
            Mock Get-PrintJob {
                @(
                    [PSCustomObject]@{ Id = 1; DocumentName = 'report.pdf'; JobStatus = 'Printing'; UserName = 'user1'; SubmittedTime = (Get-Date) },
                    [PSCustomObject]@{ Id = 2; DocumentName = 'notes.docx'; JobStatus = 'Spooling'; UserName = 'user1'; SubmittedTime = (Get-Date) }
                )
            }
        }

        It 'returns jobs in JSON mode' {
            $result = Get-UPrintQueue -PrinterName 'Office-Printer-1' -Json | ConvertFrom-Json
            $result.success | Should -Be $true
            $result.data.jobs.Count | Should -Be 2
            $result.data.jobs[0].document | Should -Be 'report.pdf'
        }

        It 'returns human-readable list by default' {
            $result = Get-UPrintQueue -PrinterName 'Office-Printer-1'
            $result | Should -Match 'report.pdf'
        }
    }

    Context 'cancel action' {
        BeforeAll {
            Mock Remove-PrintJob { } -Verifiable
        }

        It 'cancels a specific job' {
            $result = Get-UPrintQueue -PrinterName 'Office-Printer-1' -Cancel -JobId 1 -Json | ConvertFrom-Json
            $result.success | Should -Be $true
            $result.data.cancelled | Should -Be 1
            Should -InvokeVerifiable
        }
    }

    Context 'empty queue' {
        BeforeAll {
            Mock Get-PrintJob { return @() }
        }

        It 'returns empty list with success=true' {
            $result = Get-UPrintQueue -PrinterName 'Office-Printer-1' -Json | ConvertFrom-Json
            $result.success | Should -Be $true
            $result.data.jobs.Count | Should -Be 0
        }
    }
}
