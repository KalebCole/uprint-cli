function Format-UPrintOutput {
    [CmdletBinding(DefaultParameterSetName='Success')]
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter(ParameterSetName='Success')][hashtable]$Data,
        [Parameter(ParameterSetName='Error')][hashtable]$ErrorResult,
        [string[]]$Warnings = @(),
        [string]$HumanMessage,
        [switch]$Json
    )

    if ($Json) {
        $envelope = [ordered]@{
            version   = 1
            command   = $Command
            timestamp = (Get-Date -Format 'o')
            success   = ($null -eq $ErrorResult)
        }

        if ($ErrorResult) {
            $envelope.error = $ErrorResult
        } else {
            $envelope.data = if ($Data) { $Data } else { @{} }
        }

        if ($Warnings.Count -gt 0) {
            $envelope.warnings = $Warnings
        }

        return ($envelope | ConvertTo-Json -Depth 10 -Compress)
    }

    # Human mode
    if ($HumanMessage) {
        return $HumanMessage
    }

    if ($Data) {
        return ($Data | ConvertTo-Json -Depth 5)
    }
    return ''
}
