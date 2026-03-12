function New-UPrintError {
    [CmdletBinding(DefaultParameterSetName = 'Custom')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Custom')][string]$Code,
        [Parameter(Mandatory, ParameterSetName = 'Custom')][string]$Message,
        [Parameter(ParameterSetName = 'Custom')][string]$Suggestion,
        [Parameter(Mandatory, ParameterSetName = 'Known')][string]$Known
    )

    $knownErrors = @{
        'PRINTER_OFFLINE'    = @{ code = 'PRINTER_OFFLINE';    message = 'Printer is not responding';                suggestion = "Run 'uprint health' to diagnose" }
        'NOT_AUTHENTICATED'  = @{ code = 'NOT_AUTHENTICATED';  message = 'Not connected to Universal Print service'; suggestion = "Run 'Connect-UPService' to authenticate" }
        'PRINTER_NOT_FOUND'  = @{ code = 'PRINTER_NOT_FOUND';  message = 'Specified printer was not found';          suggestion = "Run 'uprint printers' to list available printers" }
        'QUEUE_DISABLED'     = @{ code = 'QUEUE_DISABLED';     message = 'Print queue is disabled';                  suggestion = "Run 'Enable-Printer' or check printer status" }
        'FILE_NOT_FOUND'     = @{ code = 'FILE_NOT_FOUND';     message = 'File to print was not found';              suggestion = 'Check the file path and try again' }
        'TIMEOUT'            = @{ code = 'TIMEOUT';            message = 'Operation timed out';                      suggestion = 'Check printer and network connectivity' }
    }

    if ($PSCmdlet.ParameterSetName -eq 'Known') {
        if ($knownErrors.ContainsKey($Known)) {
            return $knownErrors[$Known]
        }
        return @{ code = $Known; message = "Unknown error: $Known"; suggestion = $null }
    }

    return @{
        code       = $Code
        message    = $Message
        suggestion = $Suggestion
    }
}
