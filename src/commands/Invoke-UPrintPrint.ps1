function Invoke-UPrintPrint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string]$PrinterName,
        [int]$Copies = 1,
        [switch]$Duplex,
        [ValidateSet('Color', 'Mono')][string]$ColorMode = 'Color',
        [switch]$Json
    )

    if (-not (Test-Path $FilePath)) {
        $err = New-UPrintError -Known 'FILE_NOT_FOUND'
        if ($Json) { return Format-UPrintOutput -Command 'print' -ErrorResult $err -Json }
        Write-Error "File not found: $FilePath"
        return
    }

    try {
        $printer = Get-Printer -Name $PrinterName -ErrorAction Stop
        $isUP = $printer.DriverName -match 'Universal Print'

        # Resolve absolute path for print tools
        $absPath = (Resolve-Path $FilePath).Path

        # Tiered print engine
        $engine = 'unknown'
        $sumatraPath = Join-Path $PSScriptRoot "..\..\tools\SumatraPDF-3.5.2-64.exe"
        if (-not (Test-Path $sumatraPath)) {
            $sumatraPath = Join-Path $PSScriptRoot "..\..\tools\SumatraPDF.exe"
        }
        $acrobatPath = "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe"

        if (Test-Path $sumatraPath) {
            # Tier 1: SumatraPDF — fully silent, explicit printer, auto-closes
            $engine = 'SumatraPDF'
            $sumatraArgs = "-print-to `"$PrinterName`""
            if ($Copies -gt 1) {
                $sumatraArgs += " -print-settings `"${Copies}x`""
            }
            $sumatraArgs += " -silent `"$absPath`""
            Start-Process -FilePath $sumatraPath -ArgumentList $sumatraArgs -WindowStyle Hidden -Wait
        }
        elseif (Test-Path $acrobatPath) {
            # Tier 2: Acrobat /t — silent print to specific printer, then kill
            $engine = 'Acrobat'
            $proc = Start-Process -FilePath $acrobatPath -ArgumentList "/s", "/t", "`"$absPath`"", "`"$PrinterName`"" -PassThru
            Start-Sleep -Seconds 8
            if (-not $proc.HasExited) {
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            }
        }
        else {
            # Tier 3: OS Print verb — opens default app, targets default printer
            $engine = 'PrintTo'
            Start-Process -FilePath $absPath -Verb PrintTo -ArgumentList "`"$PrinterName`""
        }

        $statusMsg = if ($isUP) { 'submitted_to_cloud' } else { 'submitted' }
        $data = @{
            file    = $absPath
            printer = $PrinterName
            copies  = $Copies
            color   = $ColorMode
            duplex  = $Duplex.IsPresent
            status  = $statusMsg
            engine  = $engine
        }

        $warnings = @()
        if ($isUP) {
            $warnings += "Universal Print: job held in cloud until badge release at printer"
        }

        if ($Json) {
            return Format-UPrintOutput -Command 'print' -Data $data -Warnings $warnings -Json
        }

        $releaseMsg = if ($isUP) { "`n  Badge at $PrinterName to release." } else { '' }
        return "Job submitted to $PrinterName via $engine ($Copies copies, $ColorMode).$releaseMsg"
    }
    catch {
        $err = New-UPrintError -Code 'PRINT_FAILED' -Message $_.Exception.Message -Suggestion "Run 'uprint status --printer $PrinterName' to check"
        if ($Json) { return Format-UPrintOutput -Command 'print' -ErrorResult $err -Json }
        Write-Error $_.Exception.Message
    }
}
