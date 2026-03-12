#!/usr/bin/env pwsh
# Install SumatraPDF portable for uprint-cli silent printing
$toolsDir = Join-Path $PSScriptRoot ".." "tools"
New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null

$sumatraUrl = "https://www.sumatrapdfreader.org/dl/rel/3.5.2/SumatraPDF-3.5.2-64.zip"
$zipPath = Join-Path $toolsDir "SumatraPDF.zip"

Write-Host "Downloading SumatraPDF portable..."
Invoke-WebRequest -Uri $sumatraUrl -OutFile $zipPath -UseBasicParsing
Expand-Archive -Path $zipPath -DestinationPath $toolsDir -Force
Remove-Item $zipPath -Force
Write-Host "SumatraPDF installed at $toolsDir"
