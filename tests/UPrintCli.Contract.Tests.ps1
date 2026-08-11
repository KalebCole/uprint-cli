BeforeAll {
    function Invoke-UPrintCliProcess {
        param(
            [Parameter(Mandatory)]
            [string[]]$Arguments,

            [string]$Scenario,

            [string]$ConfigContent
        )

        $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = (Get-Command pwsh).Source
        $startInfo.WorkingDirectory = (Resolve-Path "$PSScriptRoot/..").Path
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.UseShellExecute = $false
        $profilePath = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $profilePath | Out-Null
        if ($ConfigContent) {
            $configDirectory = New-Item -ItemType Directory -Path "$profilePath/.uprint"
            Set-Content -Path "$($configDirectory.FullName)/config.json" -Value $ConfigContent
        }
        $startInfo.Environment['USERPROFILE'] = $profilePath
        $modulePath = (Resolve-Path "$PSScriptRoot/fixtures/modules").Path
        $startInfo.Environment['PSModulePath'] = $modulePath +
            [IO.Path]::PathSeparator +
            $env:PSModulePath
        if ($Scenario) {
            $startInfo.Environment['UPRINT_TEST_SCENARIO'] = $Scenario
        }

        $startInfo.ArgumentList.Add('-NoProfile')
        $startInfo.ArgumentList.Add('-NonInteractive')
        $startInfo.ArgumentList.Add('-File')
        if ($Scenario -like 'print-*') {
            $startInfo.ArgumentList.Add(
                (Resolve-Path "$PSScriptRoot/fixtures/Invoke-UPrintCliFixture.ps1").Path
            )
            $startInfo.Environment['UPRINT_CLI_ARGUMENTS'] =
                $Arguments | ConvertTo-Json -Compress
        } else {
            $startInfo.ArgumentList.Add((Resolve-Path "$PSScriptRoot/../uprint.ps1").Path)
            foreach ($argument in $Arguments) {
                $startInfo.ArgumentList.Add($argument)
            }
        }

        $process = [System.Diagnostics.Process]::Start($startInfo)
        $stdout = $process.StandardOutput.ReadToEnd().Trim()
        $stderr = $process.StandardError.ReadToEnd().Trim()
        $process.WaitForExit()

        return @{
            ExitCode = $process.ExitCode
            Stdout   = $stdout
            Stderr   = $stderr
            Profile  = $profilePath
        }
    }

    function Get-NormalizedJson {
        param(
            [Parameter(Mandatory)]
            [string]$Json
        )

        $value = $Json | ConvertFrom-Json
        $value.timestamp = '<timestamp>'
        if ($value.command -eq 'print' -and $value.data.file) {
            $value.data.file = '<file>'
        }
        return (ConvertTo-CanonicalValue -Value $value) |
            ConvertTo-Json -Depth 10 -Compress
    }

    function ConvertTo-CanonicalValue {
        param($Value)

        if ($Value -is [datetime]) {
            return $Value.ToUniversalTime().ToString('o')
        }

        if ($null -eq $Value -or $Value -is [string] -or $Value.GetType().IsPrimitive) {
            return $Value
        }

        if ($Value -is [System.Collections.IEnumerable] -and
            $Value -isnot [System.Collections.IDictionary] -and
            $Value -isnot [PSCustomObject]) {
            return @($Value | ForEach-Object {
                ConvertTo-CanonicalValue -Value $_
            })
        }

        $properties = if ($Value -is [System.Collections.IDictionary]) {
            $Value.Keys | ForEach-Object {
                [PSCustomObject]@{ Name = $_; Value = $Value[$_] }
            }
        } else {
            $Value.PSObject.Properties
        }

        $result = [ordered]@{}
        foreach ($property in ($properties | Sort-Object Name)) {
            $result[$property.Name] = ConvertTo-CanonicalValue -Value $property.Value
        }
        return [PSCustomObject]$result
    }
}

Describe 'U-Print CLI contract' {
    It 'returns help in one JSON envelope' {
        $expected = Get-Content "$PSScriptRoot/fixtures/help.success.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @('--json')

        $result.ExitCode | Should -Be 0
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'returns a JSON invalid-argument result for an unknown command' {
        $expected = Get-Content "$PSScriptRoot/fixtures/arguments.invalid.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @('bogus', '--json')

        $result.ExitCode | Should -Be 3
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'returns a JSON invalid-argument result when no printer is selected' {
        $expected = Get-Content "$PSScriptRoot/fixtures/printer.required.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @('status', '--json')

        $result.ExitCode | Should -Be 3
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'returns exit code 3 when the print input file does not exist' {
        $expected = Get-Content "$PSScriptRoot/fixtures/print.file-not-found.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'print',
            "$TestDrive/missing.pdf",
            '--printer',
            'Office Printer',
            '--json'
        )

        $result.ExitCode | Should -Be 3
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'rejects queue cancellation without a selector' {
        $expected = Get-Content "$PSScriptRoot/fixtures/queue.cancel-invalid.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'queue',
            'cancel',
            '--printer',
            'Office Printer',
            '--json'
        )

        $result.ExitCode | Should -Be 3
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'rejects a key argument for config get' {
        $expected = Get-Content "$PSScriptRoot/fixtures/config.get-invalid.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'config',
            'get',
            'timeout',
            '--json'
        )

        $result.ExitCode | Should -Be 3
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'rejects an unknown configuration key without writing config' {
        $expected = Get-Content "$PSScriptRoot/fixtures/config.key-invalid.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'config',
            'set',
            'extra',
            'value',
            '--json'
        )

        $result.ExitCode | Should -Be 3
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
        "$($result.Profile)/.uprint/config.json" | Should -Not -Exist
    }

    It 'writes one configuration field and returns the complete configuration' {
        $expected = Get-Content "$PSScriptRoot/fixtures/config.set.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'config',
            'set',
            'timeout',
            '5000',
            '--json'
        )

        $result.ExitCode | Should -Be 0
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
        "$($result.Profile)/.uprint/config.json" | Should -Exist
    }

    It 'rejects a missing copies value' {
        $expected = Get-Content "$PSScriptRoot/fixtures/print.copies-invalid.json" -Raw
        $file = New-Item -ItemType File -Path "$TestDrive/report.pdf" -Force

        $result = Invoke-UPrintCliProcess -Arguments @(
            'print',
            $file.FullName,
            '--copies',
            '--printer',
            'Office Printer',
            '--json'
        )

        $result.ExitCode | Should -Be 3
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'rejects conflicting color-mode options' {
        $expected = Get-Content "$PSScriptRoot/fixtures/print.color-invalid.json" -Raw
        $file = New-Item -ItemType File -Path "$TestDrive/slides.pdf" -Force

        $result = Invoke-UPrintCliProcess -Arguments @(
            'print',
            $file.FullName,
            '--color',
            '--mono',
            '--printer',
            'Office Printer',
            '--json'
        )

        $result.ExitCode | Should -Be 3
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'rejects an unknown command option' {
        $expected = Get-Content "$PSScriptRoot/fixtures/arguments.unknown-option.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'status',
            '--bogus',
            '--printer',
            'Office Printer',
            '--json'
        )

        $result.ExitCode | Should -Be 3
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'selects a setup printer without an interactive JSON prompt' {
        $expected = Get-Content "$PSScriptRoot/fixtures/setup.success.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'setup',
            '--printer',
            'Office UP',
            '--json'
        )

        $result.ExitCode | Should -Be 0
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'returns exit code 1 when the selected printer is not found' {
        $expected = Get-Content "$PSScriptRoot/fixtures/status.not-found.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'status',
            '--printer',
            'Missing Printer',
            '--json'
        )

        $result.ExitCode | Should -Be 1
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'returns the selected printer status' {
        $expected = Get-Content "$PSScriptRoot/fixtures/status.success.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'status',
            '--printer',
            'Office UP',
            '--json'
        )

        $result.ExitCode | Should -Be 0
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'filters the printer list with the short Universal Print option' {
        $expected = Get-Content "$PSScriptRoot/fixtures/printers.universal-only.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'printers',
            '-u',
            '--json'
        )

        $result.ExitCode | Should -Be 0
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'returns all installed printers' {
        $expected = Get-Content "$PSScriptRoot/fixtures/printers.success.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @('printers', '--json')

        $result.ExitCode | Should -Be 0
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'returns a successful empty printer list' {
        $expected = Get-Content "$PSScriptRoot/fixtures/printers.empty.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @('printers', '--json') `
            -Scenario 'no-printers'

        $result.ExitCode | Should -Be 0
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'returns an operational error when setup finds no printers' {
        $expected = Get-Content "$PSScriptRoot/fixtures/setup.no-printers.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'setup',
            '--printer',
            'Office UP',
            '--json'
        ) -Scenario 'no-printers'

        $result.ExitCode | Should -Be 1
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'returns exit code 1 when the queue cannot be read' {
        $expected = Get-Content "$PSScriptRoot/fixtures/queue.error.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'queue',
            '--printer',
            'Office UP',
            '--json'
        ) -Scenario 'queue-error'

        $result.ExitCode | Should -Be 1
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'returns a nonempty queue' {
        $expected = Get-Content "$PSScriptRoot/fixtures/queue.nonempty.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'queue',
            '--printer',
            'Office UP',
            '--json'
        )

        $result.ExitCode | Should -Be 0
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'returns an empty queue' {
        $expected = Get-Content "$PSScriptRoot/fixtures/queue.empty.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'queue',
            '--printer',
            'Office UP',
            '--json'
        ) -Scenario 'queue-empty'

        $result.ExitCode | Should -Be 0
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'cancels one queue job by ID' {
        $expected = Get-Content "$PSScriptRoot/fixtures/queue.cancel-one.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'queue',
            'cancel',
            '7',
            '--printer',
            'Office UP',
            '--json'
        )

        $result.ExitCode | Should -Be 0
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'cancels all queue jobs with the explicit all option' {
        $expected = Get-Content "$PSScriptRoot/fixtures/queue.cancel-all.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'queue',
            'cancel',
            '--all',
            '--printer',
            'Office UP',
            '--json'
        )

        $result.ExitCode | Should -Be 0
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'returns a healthy diagnostic result' {
        $expected = Get-Content "$PSScriptRoot/fixtures/health.healthy.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'health',
            '--printer',
            'Office UP',
            '--json'
        )

        $result.ExitCode | Should -Be 0
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'returns warnings for an unhealthy diagnostic result' {
        $expected = Get-Content "$PSScriptRoot/fixtures/health.unhealthy.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'health',
            '--printer',
            'Office UP',
            '--json'
        ) -Scenario 'spooler-stopped'

        $result.ExitCode | Should -Be 0
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'returns the complete default configuration' {
        $expected = Get-Content "$PSScriptRoot/fixtures/config.get.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @('config', 'get', '--json')

        $result.ExitCode | Should -Be 0
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'warns when the selected printer has more than five jobs' {
        $expected = Get-Content "$PSScriptRoot/fixtures/status.high-job-count.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'status',
            '--printer',
            'Office UP',
            '--json'
        ) -Scenario 'high-job-count'

        $result.ExitCode | Should -Be 0
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'submits a Universal Print job through SumatraPDF' {
        $expected = Get-Content "$PSScriptRoot/fixtures/print.universal-sumatra.json" -Raw
        $file = New-Item -ItemType File -Path "$TestDrive/up-report.pdf" -Force

        $result = Invoke-UPrintCliProcess -Arguments @(
            'print',
            $file.FullName,
            '--copies',
            '2',
            '--duplex',
            '--mono',
            '--printer',
            'Office UP',
            '--json'
        ) -Scenario 'print-sumatra'

        $result.ExitCode | Should -Be 0
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'submits a local job through Acrobat when SumatraPDF is absent' {
        $expected = Get-Content "$PSScriptRoot/fixtures/print.local-acrobat.json" -Raw
        $file = New-Item -ItemType File -Path "$TestDrive/acrobat-report.pdf" -Force

        $result = Invoke-UPrintCliProcess -Arguments @(
            'print',
            $file.FullName,
            '--printer',
            'Local Printer',
            '--json'
        ) -Scenario 'print-acrobat'

        $result.ExitCode | Should -Be 0
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'submits a local job through PrintTo when other engines are absent' {
        $expected = Get-Content "$PSScriptRoot/fixtures/print.local-printto.json" -Raw
        $file = New-Item -ItemType File -Path "$TestDrive/printto-report.pdf" -Force

        $result = Invoke-UPrintCliProcess -Arguments @(
            'print',
            $file.FullName,
            '--printer',
            'Local Printer',
            '--json'
        ) -Scenario 'print-printto'

        $result.ExitCode | Should -Be 0
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'returns exit code 1 when print submission fails' {
        $expected = Get-Content "$PSScriptRoot/fixtures/print.failed.json" -Raw
        $file = New-Item -ItemType File -Path "$TestDrive/failed-report.pdf" -Force

        $result = Invoke-UPrintCliProcess -Arguments @(
            'print',
            $file.FullName,
            '--printer',
            'Local Printer',
            '--json'
        ) -Scenario 'print-failed'

        $result.ExitCode | Should -Be 1
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'returns exit code 1 when printers cannot be listed' {
        $expected = Get-Content "$PSScriptRoot/fixtures/printers.failed.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'printers',
            '--json'
        ) -Scenario 'list-error'

        $result.ExitCode | Should -Be 1
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'rejects a job ID together with the all selector' {
        $expected = Get-Content "$PSScriptRoot/fixtures/queue.cancel-conflict.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'queue',
            'cancel',
            '7',
            '--all',
            '--printer',
            'Office UP',
            '--json'
        )

        $result.ExitCode | Should -Be 3
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'rejects config set without a value' {
        $expected = Get-Content "$PSScriptRoot/fixtures/config.set-invalid.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'config',
            'set',
            'timeout',
            '--json'
        )

        $result.ExitCode | Should -Be 3
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'rejects a nonnumeric timeout value' {
        $expected = Get-Content "$PSScriptRoot/fixtures/config.value-invalid.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'config',
            'set',
            'timeout',
            'nope',
            '--json'
        )

        $result.ExitCode | Should -Be 3
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'rejects a non-Boolean configuration value' {
        $expected = Get-Content "$PSScriptRoot/fixtures/config.boolean-invalid.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'config',
            'set',
            'jsonOutput',
            'maybe',
            '--json'
        )

        $result.ExitCode | Should -Be 3
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'requires an explicit setup printer in JSON mode' {
        $expected = Get-Content "$PSScriptRoot/fixtures/setup.printer-required.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @('setup', '--json')

        $result.ExitCode | Should -Be 3
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'returns an error when the setup printer is not installed' {
        $expected = Get-Content "$PSScriptRoot/fixtures/setup.printer-not-found.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'setup',
            '--printer',
            'Missing Printer',
            '--json'
        )

        $result.ExitCode | Should -Be 1
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'rejects an unknown print option' {
        $expected = Get-Content "$PSScriptRoot/fixtures/print.unknown-option.json" -Raw
        $file = New-Item -ItemType File -Path "$TestDrive/unknown-option.pdf" -Force

        $result = Invoke-UPrintCliProcess -Arguments @(
            'print',
            $file.FullName,
            '--bogus',
            '--printer',
            'Local Printer',
            '--json'
        )

        $result.ExitCode | Should -Be 3
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'rejects an extra print argument' {
        $expected = Get-Content "$PSScriptRoot/fixtures/print.extra-argument.json" -Raw
        $file = New-Item -ItemType File -Path "$TestDrive/extra-argument.pdf" -Force

        $result = Invoke-UPrintCliProcess -Arguments @(
            'print',
            $file.FullName,
            'extra',
            '--printer',
            'Local Printer',
            '--json'
        )

        $result.ExitCode | Should -Be 3
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'rejects a zero print job ID' {
        $expected = Get-Content "$PSScriptRoot/fixtures/queue.job-id-invalid.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'queue',
            'cancel',
            '0',
            '--printer',
            'Office UP',
            '--json'
        )

        $result.ExitCode | Should -Be 3
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'rejects an extra queue cancellation argument' {
        $expected = Get-Content "$PSScriptRoot/fixtures/queue.extra-argument.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'queue',
            'cancel',
            '7',
            'extra',
            '--printer',
            'Office UP',
            '--json'
        )

        $result.ExitCode | Should -Be 3
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'rejects an unknown queue subcommand' {
        $expected = Get-Content "$PSScriptRoot/fixtures/queue.subcommand-invalid.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'queue',
            'remove',
            '--printer',
            'Office UP',
            '--json'
        )

        $result.ExitCode | Should -Be 3
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'rejects an unknown config subcommand' {
        $expected = Get-Content "$PSScriptRoot/fixtures/config.subcommand-invalid.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'config',
            'remove',
            '--json'
        )

        $result.ExitCode | Should -Be 3
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'rejects an extra setup argument' {
        $expected = Get-Content "$PSScriptRoot/fixtures/setup.extra-argument.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'setup',
            'extra',
            '--printer',
            'Office UP',
            '--json'
        )

        $result.ExitCode | Should -Be 3
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'rejects an unknown printers option' {
        $expected = Get-Content "$PSScriptRoot/fixtures/printers.unknown-option.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'printers',
            '--bogus',
            '--json'
        )

        $result.ExitCode | Should -Be 3
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'rejects an unknown health option' {
        $expected = Get-Content "$PSScriptRoot/fixtures/health.unknown-option.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'health',
            '--bogus',
            '--printer',
            'Office UP',
            '--json'
        )

        $result.ExitCode | Should -Be 3
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'returns JSON when the printer option has no value' {
        $expected = Get-Content "$PSScriptRoot/fixtures/printer.value-invalid.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'status',
            '--printer',
            '--json'
        )

        $result.ExitCode | Should -Be 3
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'keeps malformed configuration warnings out of JSON stdout' {
        $expected = Get-Content "$PSScriptRoot/fixtures/config.get.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'config',
            'get',
            '--json'
        ) -ConfigContent '{invalid'

        $result.ExitCode | Should -Be 0
        $result.Stderr | Should -Match 'Failed to parse config'
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'ignores unknown keys in an existing configuration file' {
        $expected = Get-Content "$PSScriptRoot/fixtures/config.get.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'config',
            'get',
            '--json'
        ) -ConfigContent '{"extra":"value"}'

        $result.ExitCode | Should -Be 0
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'keeps a numeric printer name as text' {
        $expected = Get-Content "$PSScriptRoot/fixtures/config.default-printer.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'config',
            'set',
            'defaultPrinter',
            '123',
            '--json'
        )

        $result.ExitCode | Should -Be 0
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'returns JSON when the print file argument is missing' {
        $expected = Get-Content "$PSScriptRoot/fixtures/print.file-required.json" -Raw

        $result = Invoke-UPrintCliProcess -Arguments @(
            'print',
            '--printer',
            'Local Printer',
            '--json'
        )

        $result.ExitCode | Should -Be 3
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'uses configured JSON output and the configured default printer' {
        $expected = Get-Content "$PSScriptRoot/fixtures/status.success.json" -Raw
        $config = @{
            defaultPrinter = 'Office UP'
            autoWake       = $true
            timeout        = 10000
            jsonOutput     = $true
        } | ConvertTo-Json -Compress

        $result = Invoke-UPrintCliProcess -Arguments @('status') `
            -ConfigContent $config

        $result.ExitCode | Should -Be 0
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'does not use the configured default for JSON setup' {
        $expected = Get-Content "$PSScriptRoot/fixtures/setup.printer-required.json" -Raw
        $config = @{
            defaultPrinter = 'Office UP'
            autoWake       = $true
            timeout        = 10000
            jsonOutput     = $false
        } | ConvertTo-Json -Compress

        $result = Invoke-UPrintCliProcess -Arguments @(
            'setup',
            '--json'
        ) -Scenario 'no-printers' -ConfigContent $config

        $result.ExitCode | Should -Be 3
        $result.Stderr | Should -BeNullOrEmpty
        (Get-NormalizedJson -Json $result.Stdout) |
            Should -Be (Get-NormalizedJson -Json $expected)
    }

    It 'rejects the printer option for interactive setup' {
        $result = Invoke-UPrintCliProcess -Arguments @(
            'setup',
            '--printer',
            'Office UP'
        )

        $result.ExitCode | Should -Be 3
        $result.Stdout | Should -BeNullOrEmpty
        $result.Stderr | Should -Match '--printer requires JSON mode for setup'
    }
}
