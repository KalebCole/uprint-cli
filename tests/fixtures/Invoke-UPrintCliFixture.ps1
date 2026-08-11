param()

$cliArguments = @($env:UPRINT_CLI_ARGUMENTS | ConvertFrom-Json)

function global:Test-Path {
    [CmdletBinding()]
    param([string]$Path)

    if ($Path -match 'SumatraPDF-3\.5\.2-64\.exe$') {
        return $env:UPRINT_TEST_SCENARIO -eq 'print-sumatra'
    }
    if ($Path -match 'SumatraPDF\.exe$') {
        return $false
    }
    if ($Path -eq 'C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe') {
        return $env:UPRINT_TEST_SCENARIO -eq 'print-acrobat'
    }
    return Microsoft.PowerShell.Management\Test-Path -Path $Path
}

function global:Start-Process {
    [CmdletBinding()]
    param(
        [string]$FilePath,
        [object[]]$ArgumentList,
        [string]$WindowStyle,
        [switch]$Wait,
        [switch]$PassThru,
        [string]$Verb
    )

    if ($env:UPRINT_TEST_SCENARIO -eq 'print-failed') {
        throw 'Fixture print failure'
    }

    if ($PassThru) {
        return [PSCustomObject]@{ HasExited = $true; Id = 1234 }
    }
}

function global:Start-Sleep {
    [CmdletBinding()]
    param([int]$Seconds)
}

$global:LASTEXITCODE = 0
& "$PSScriptRoot/../../uprint.ps1" @cliArguments
exit $LASTEXITCODE
