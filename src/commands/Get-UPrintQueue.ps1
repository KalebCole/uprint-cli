function Get-UPrintQueue {
    [CmdletBinding()]
    param(
        [string]$PrinterName,
        [switch]$Cancel,
        [int]$JobId,
        [switch]$CancelAll,
        [switch]$Json
    )

    try {
        if ($Cancel) {
            if ($CancelAll) {
                $jobs = @(Get-PrintJob -PrinterName $PrinterName -ErrorAction SilentlyContinue)
                foreach ($job in $jobs) {
                    Remove-PrintJob -PrinterObject $job -ErrorAction Stop
                }
                $data = @{ cancelled = $jobs.Count; printer = $PrinterName }
            } else {
                Remove-PrintJob -PrinterName $PrinterName -ID $JobId -ErrorAction Stop
                $data = @{ cancelled = $JobId; printer = $PrinterName }
            }

            if ($Json) { return Format-UPrintOutput -Command 'queue' -Data $data -Json }
            return "✅ Cancelled job(s) on $PrinterName"
        }

        # List mode (default)
        $jobs = @(Get-PrintJob -PrinterName $PrinterName -ErrorAction SilentlyContinue)

        $jobList = $jobs | ForEach-Object {
            @{
                id        = $_.Id
                document  = $_.DocumentName
                status    = $_.JobStatus.ToString()
                user      = $_.UserName
                submitted = $_.SubmittedTime.ToString('o')
            }
        }

        $data = @{ jobs = @($jobList); count = @($jobList).Count; printer = $PrinterName }

        if ($Json) {
            return Format-UPrintOutput -Command 'queue' -Data $data -Json
        }

        if ($jobs.Count -eq 0) {
            return "Print queue for $PrinterName is empty."
        }
        $lines = @("Print Queue — $PrinterName ($($jobs.Count) jobs):", "")
        foreach ($j in $jobList) {
            $lines += "  [$($j.id)] $($j.document) — $($j.status) ($($j.user))"
        }
        return ($lines -join "`n")
    }
    catch {
        $err = New-UPrintError -Code 'QUEUE_ERROR' -Message $_.Exception.Message -Suggestion "Run 'uprint status' to check printer"
        if ($Json) { return Format-UPrintOutput -Command 'queue' -ErrorResult $err -Json }
        Write-Error $_.Exception.Message
    }
}
