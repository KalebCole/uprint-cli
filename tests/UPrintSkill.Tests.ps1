BeforeAll {
    Import-Module powershell-yaml -ErrorAction Stop
    $skill = Get-Content "$PSScriptRoot/../SKILL.md" -Raw
    $readme = Get-Content "$PSScriptRoot/../README.md" -Raw
    $contract = Get-Content "$PSScriptRoot/../spec/uprint-cli-contract.yaml" -Raw |
        ConvertFrom-Yaml
}

Describe 'U-Print agent skill' {
    It 'resolves the CLI independently of the skill directory' {
        $skill | Should -Match 'UPRINT_CLI_PATH'
        $skill | Should -Match 'Get-Command uprint\.ps1'
        $skill | Should -Match 'Resolve-Path \.\\uprint\.ps1'
        $skill | Should -Not -Match '\$PSScriptRoot\\uprint\.ps1'
    }

    It 'installs in the Copilot personal skill directory' {
        $readme | Should -Match '\.copilot\\skills\\uprint-cli'
        $readme | Should -Match 'Join-Path \$skillDirectory ''SKILL\.md'''
        $readme | Should -Match '/skills reload'
        $readme | Should -Not -Match 'uprint-cli\.skill\.md'
    }

    It 'uses machine-readable help and output' {
        $skill | Should -Match '& \$uprint --help --json'
        $skill | Should -Match 'Use `--json` for every agent\s+call'
        $skill | Should -Match 'exactly one JSON envelope'
    }

    It 'limits printer selection to printers installed in Windows' {
        $skill | Should -Match 'installed-printers-only'
        $skill | Should -Match '& \$uprint printers --json'
        $skill | Should -Match 'configured default'
        $skill | Should -Match '--printer <name>'
        $skill | Should -Match 'installed in Windows'
    }

    It 'requires explicit intent for every mutation' {
        foreach ($mutation in @(
            'print',
            'setup',
            'config set',
            'queue cancel'
        )) {
            $skill | Should -Match ([regex]::Escape($mutation))
        }
        $skill | Should -Match 'explicit\s+user request'
        $skill | Should -Match 'explicitly requests cancellation\s+of all jobs'
    }

    It 'uses the contract success signals for a submission' {
        foreach ($code in $contract.exitCodes.Keys) {
            $skill | Should -Match (
                [regex]::Escape("Exit $code")
            )
        }
        $skill | Should -Match '`success: true`'
        $skill | Should -Match '`submitted`'
        $skill | Should -Match '`submitted_to_cloud`'
        $skill | Should -Match 'does not confirm physical\s+output'
    }
}
