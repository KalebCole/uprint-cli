BeforeAll {
    Import-Module powershell-yaml -ErrorAction Stop
    $contractPath = "$PSScriptRoot/../spec/uprint-cli-contract.yaml"
    $contract = Get-Content $contractPath -Raw | ConvertFrom-Yaml
}

Describe 'U-Print CLI contract document' {
    It 'has the required identity and top-level sections' {
        $contract.kind | Should -Be 'uprint-cli-contract'
        $contract.contractVersion | Should -Be 1
        $contract.platform | Should -Not -BeNullOrEmpty
        $contract.configuration | Should -Not -BeNullOrEmpty
        $contract.globalOptions | Should -Not -BeNullOrEmpty
        $contract.jsonEnvelope | Should -Not -BeNullOrEmpty
        $contract.errors | Should -Not -BeNullOrEmpty
        $contract.exitCodes | Should -Not -BeNullOrEmpty
        $contract.commands | Should -Not -BeNullOrEmpty
        $contract.printSubmission | Should -Not -BeNullOrEmpty
        $contract.fixtures | Should -Not -BeNullOrEmpty
    }

    It 'references valid normalized JSON fixtures' {
        foreach ($fixture in $contract.fixtures) {
            $fixturePath = Join-Path "$PSScriptRoot/.." $fixture.path
            $fixturePath | Should -Exist

            $json = Get-Content $fixturePath -Raw | ConvertFrom-Json
            $json.version | Should -Be 1
            $json.timestamp | Should -Be '<timestamp>'
            $json.command | Should -Not -BeNullOrEmpty
            $json.success | Should -BeOfType [bool]
        }
    }
}
