---
name: uprint-cli
description: >
  Universal Print agentic CLI. List printers, check status, print files,
  manage queue, run health checks. Works with Microsoft Universal Print
  printers on enterprise Windows devices. Use when user asks to print,
  check printers, manage print queue, or diagnose print issues.
  Triggers: "print", "printer", "uprint", "print queue", "print status",
  "Universal Print", "print job", "print health"
---

# Universal Print CLI

## Quick Reference

```powershell
# Setup (first run)
& "$PSScriptRoot\uprint.ps1" setup

# List printers
& "$PSScriptRoot\uprint.ps1" printers --json

# Printer status
& "$PSScriptRoot\uprint.ps1" status --json

# Print a file
& "$PSScriptRoot\uprint.ps1" print "C:\path\to\file.pdf"

# View print queue
& "$PSScriptRoot\uprint.ps1" queue --json

# Cancel all print jobs
& "$PSScriptRoot\uprint.ps1" queue cancel --all

# Health check
& "$PSScriptRoot\uprint.ps1" health --json

# Config
& "$PSScriptRoot\uprint.ps1" config get
& "$PSScriptRoot\uprint.ps1" config set defaultPrinter "Office-Printer-1"
```

## Exit Codes
- 0: Success
- 1: General error
- 3: Invalid input (bad args, missing file)

## JSON Output
All commands support `--json` for structured output:
```json
{"version":1,"command":"status","timestamp":"...","success":true,"data":{...}}
```
