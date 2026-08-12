# U-Print

U-Print is a PowerShell CLI for printers installed in Windows. It can list
printers, inspect status, submit files, manage print jobs, and run health
checks. Human-readable output is the default. Versioned JSON output supports
AI agents and automation.

U-Print supports Microsoft Universal Print printers and other installed
Windows printers. It does not search a cloud or building printer directory.

## Requirements

- Windows 10 or 11
- Windows PrintManagement cmdlets
- The Windows Spooler service
- Windows PowerShell 5.1 or PowerShell 7

The CLI has no additional runtime dependency.

## Quick start

```powershell
git clone https://github.com/KalebCole/uprint-cli.git
cd uprint-cli

# Select and save a default printer.
.\uprint.ps1 setup

# Inspect the default printer.
.\uprint.ps1 status

# Submit a file.
.\uprint.ps1 print ".\report.pdf"
```

`setup` is interactive in human mode. It lists printers installed in Windows
and saves the selected printer in `%USERPROFILE%\.uprint\config.json`.

## Select a printer

Commands use printers in this order:

1. The printer supplied with `--printer <name>`.
2. The configured `defaultPrinter`.

List installed printers before you use another office or building:

```powershell
.\uprint.ps1 printers --json
.\uprint.ps1 status --printer "Office-Printer-2" --json
.\uprint.ps1 print ".\report.pdf" --printer "Office-Printer-2" --json
```

If the required printer is not listed, install it in Windows first or contact
your IT team.

Agents must use noninteractive JSON setup:

```powershell
.\uprint.ps1 setup --printer "Office-Printer-2" --json
```

## Commands

| Command | Purpose |
| --- | --- |
| `.\uprint.ps1 setup` | Interactively select and save a default printer. |
| `.\uprint.ps1 setup --printer <name> --json` | Save an explicit printer without a prompt. |
| `.\uprint.ps1 printers [--universal-only\|-u]` | List installed printers. |
| `.\uprint.ps1 status` | Inspect one printer and its pending print-job count. |
| `.\uprint.ps1 print <file>` | Submit one file to a print engine. |
| `.\uprint.ps1 queue` | List print jobs for one printer. |
| `.\uprint.ps1 queue cancel <job-id>` | Cancel one print job. |
| `.\uprint.ps1 queue cancel --all` | Cancel all print jobs for one printer. |
| `.\uprint.ps1 health` | Check the Spooler, printer, queue, and Universal Print driver. |
| `.\uprint.ps1 config get` | Return the complete configuration. |
| `.\uprint.ps1 config set <key> <value>` | Set one supported configuration value. |

Cancel by print job ID when possible. Use `queue cancel --all` only when all
jobs on the selected printer must be cancelled.

Global options:

| Option | Purpose |
| --- | --- |
| `--json` | Emit one version 1 JSON envelope on standard output. |
| `--printer <name>` | Override the configured printer for one call. |
| `--help` | Return human help or agent help data. |

Print options:

```text
--copies <count>    Positive integer. Default: 1.
--duplex            Request duplex output.
--color             Request color output. Default.
--mono              Request monochrome output.
```

`--color` and `--mono` are mutually exclusive.

Configuration keys are `defaultPrinter`, `autoWake`, `timeout`, and
`jsonOutput`.

## Submission semantics

U-Print selects the first available print engine in this order:

1. `tools\SumatraPDF-3.5.2-64.exe`
2. `tools\SumatraPDF.exe`
3. Adobe Acrobat
4. Windows `PrintTo`

A successful command means that U-Print observed no submission error. It does
not confirm that paper came out.

- `submitted_to_cloud`: Universal Print accepted the submission. Badge release
  at the printer can still be required.
- `submitted`: Another installed printer accepted the submission.

## JSON for agents

Use agent help as the runtime command contract:

```powershell
.\uprint.ps1 --help --json
```

Use `--json` for every agent call. JSON mode writes exactly one envelope to
standard output.

Success:

```json
{
  "version": 1,
  "command": "status",
  "timestamp": "2026-01-15T09:30:00.0000000-08:00",
  "success": true,
  "data": {
    "name": "Office UP",
    "status": "Normal",
    "driver": "Universal Print Class Driver",
    "port": "PORT-UP",
    "type": "Local",
    "shared": false,
    "pendingJobs": 1,
    "isUP": true
  }
}
```

Failure:

```json
{
  "version": 1,
  "command": "status",
  "timestamp": "2026-01-15T09:31:12.0000000-08:00",
  "success": false,
  "error": {
    "code": "PRINTER_NOT_FOUND",
    "message": "Specified printer was not found",
    "suggestion": "Run 'uprint printers' to list available printers"
  }
}
```

An optional `warnings` array can accompany a successful result.

Process exit codes:

| Code | Meaning |
| --- | --- |
| `0` | Success |
| `1` | Operational error |
| `3` | Invalid input, including a missing file |

## Install the Copilot CLI skill

From the repository root:

```powershell
$uprintPath = (Resolve-Path ".\uprint.ps1").Path
[Environment]::SetEnvironmentVariable('UPRINT_CLI_PATH', $uprintPath, 'User')
$env:UPRINT_CLI_PATH = $uprintPath

$skillDirectory = Join-Path $env:USERPROFILE '.copilot\skills\uprint-cli'
New-Item -ItemType Directory -Path $skillDirectory -Force | Out-Null
Copy-Item ".\SKILL.md" (Join-Path $skillDirectory 'SKILL.md')
```

Restart the process that launches Copilot CLI so it receives
`UPRINT_CLI_PATH`. In an existing Copilot CLI session, reload and inspect the
skill:

```text
/skills reload
/skills info uprint-cli
```

The skill resolves the CLI, discovers installed printers, applies mutation
safeguards, and checks submission results.

## Contract and development

The normative interface is
[`spec/uprint-cli-contract.yaml`](spec/uprint-cli-contract.yaml). Normalized
examples are in [`tests/fixtures/`](tests/fixtures/).

Development tests require PowerShell 7, Pester 5.7.1, and
[`powershell-yaml`](https://github.com/cloudbase/powershell-yaml):

```powershell
Import-Module Pester -RequiredVersion 5.7.1
Invoke-Pester tests/ -Output Detailed
```

Use conventional commits for contributions.

## License

[MIT](LICENSE)
