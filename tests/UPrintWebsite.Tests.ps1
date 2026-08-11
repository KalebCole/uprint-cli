BeforeAll {
    Import-Module powershell-yaml -ErrorAction Stop
    $contract = Get-Content "$PSScriptRoot/../spec/uprint-cli-contract.yaml" -Raw |
        ConvertFrom-Yaml
    $websitePath = "$PSScriptRoot/../docs/index.html"
    $website = Get-Content $websitePath -Raw
    $rig = Get-Content "$PSScriptRoot/../docs/rig.js" -Raw
    $websiteGuide = Get-Content "$PSScriptRoot/../docs/README.md" -Raw
    $visibleWebsite = [regex]::Replace(
        $website,
        '<!--.*?-->',
        '',
        [Text.RegularExpressions.RegexOptions]::Singleline
    )

    function Get-WebsiteJsonExample {
        param([Parameter(Mandatory)][string]$Id)

        $match = [regex]::Match(
            $website,
            '<pre id="' + [regex]::Escape($Id) + '" class="code">(.*?)</pre>',
            [Text.RegularExpressions.RegexOptions]::Singleline
        )
        if (-not $match.Success) {
            throw "Website JSON example '$Id' was not found."
        }

        $withoutMarkup = [regex]::Replace($match.Groups[1].Value, '<[^>]+>', '')
        return [Net.WebUtility]::HtmlDecode($withoutMarkup) | ConvertFrom-Json
    }
}

Describe 'U-Print website contract' {
    It 'documents the current PowerShell runtime' {
        $visibleWebsite | Should -Match ([regex]::Escape('.\uprint.ps1 setup'))
        $visibleWebsite | Should -Match 'PowerShell 5\.1'
        $visibleWebsite |
            Should -Not -Match 'Node\.js|npm (ci|install|run)|bin/uprint\.js|TYPESCRIPT'
    }

    It 'documents human output by default and the contract exit codes' {
        $visibleWebsite |
            Should -Match '<dt><code>--json</code></dt><dd>Emit one JSON envelope'
        $visibleWebsite | Should -Not -Match '--human'
        $visibleWebsite |
            Should -Match '<dt><code>1</code></dt><dd>Operational error'
        $visibleWebsite |
            Should -Match '<dt><code>3</code></dt><dd>Invalid input'
    }

    It 'documents the version 1 configuration fields and defaults' {
        foreach ($key in $contract.configuration.required) {
            $default = $contract.configuration.properties[$key].default
            $defaultText = if ($null -eq $default) {
                'null'
            } elseif ($default -is [bool]) {
                $default.ToString().ToLowerInvariant()
            } else {
                $default.ToString()
            }
            $visibleWebsite | Should -Match (
                '<dt><code>' + [regex]::Escape($key) +
                '</code></dt><dd>.*Default <code>' +
                [regex]::Escape($defaultText) + '</code>'
            )
        }
        $visibleWebsite | Should -Not -Match 'timeoutMs|Known bug'
    }

    It 'documents JSON setup and the shipped root agent skill' {
        $visibleWebsite |
            Should -Match (
                [regex]::Escape('.\uprint.ps1 setup --printer &lt;name&gt; --json')
            )
        $visibleWebsite |
            Should -Match 'github\.com/kalebcole/uprint-cli/blob/master/SKILL\.md'
        $visibleWebsite |
            Should -Not -Match 'skills/uprint/SKILL\.md|uprint skill install|NOT SHIPPED YET'
    }

    It 'keeps the demonstration inside the observable submission boundary' {
        $rig | Should -Match ([regex]::Escape('.\\uprint.ps1 print '))
        $rig | Should -Match ([regex]::Escape(' --json'))
        $rig | Should -Match 'SUBMITTED TO CLOUD'
        $rig | Should -Not -Match 'RELEASED AT DEVICE'
        $visibleWebsite | Should -Match 'CLI OBSERVATION'
        $visibleWebsite | Should -Match 'downstream illustration'
    }

    It 'describes the real print-engine fallback without a silent-print promise' {
        $visibleWebsite |
            Should -Match '(?s)SumatraPDF.*Acrobat.*PrintTo'
        $visibleWebsite |
            Should -Not -Match 'prints silently|Nothing opens|names the install command'
    }

    It 'shows every required field in the status success example' {
        foreach ($field in @(
            'name',
            'status',
            'driver',
            'port',
            'type',
            'shared',
            'pendingJobs',
            'isUP'
        )) {
            $visibleWebsite |
                Should -Match ([regex]::Escape('"' + $field + '"'))
        }
    }

    It 'uses the normalized status fixtures for its JSON examples' {
        $success = Get-WebsiteJsonExample -Id 'statusSuccess'
        $failure = Get-WebsiteJsonExample -Id 'statusFailure'
        $expectedSuccess = Get-Content "$PSScriptRoot/fixtures/status.success.json" -Raw |
            ConvertFrom-Json
        $expectedFailure = Get-Content "$PSScriptRoot/fixtures/status.not-found.json" -Raw |
            ConvertFrom-Json

        $success.command | Should -Be $expectedSuccess.command
        $success.success | Should -Be $expectedSuccess.success
        foreach ($property in $expectedSuccess.data.PSObject.Properties) {
            $success.data.($property.Name) | Should -Be $property.Value
        }

        $failure.command | Should -Be $expectedFailure.command
        $failure.success | Should -Be $expectedFailure.success
        foreach ($property in $expectedFailure.error.PSObject.Properties) {
            $failure.error.($property.Name) | Should -Be $property.Value
        }
    }

    It 'documents the current website source and verification path' {
        $websiteGuide | Should -Match 'master:/docs'
        $websiteGuide | Should -Match 'UPrintWebsite\.Tests\.ps1'
        $websiteGuide | Should -Match 'impeccable/scripts/detect\.mjs'
        $websiteGuide |
            Should -Not -Match 'two repositories|TypeScript port|manual copy|kalebcole_microsoft'
    }
}
