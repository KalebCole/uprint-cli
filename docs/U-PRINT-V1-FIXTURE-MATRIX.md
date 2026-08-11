# U-Print version 1 fixture matrix

## Purpose

The normalized JSON fixtures are the acceptance examples for
`spec/uprint-cli-contract.yaml`. Each fixture uses envelope version `1`, the
timestamp placeholder `<timestamp>`, and stable test values.

The process tests invoke `uprint.ps1` and observe standard output, standard
error, and the process exit code (`tests/UPrintCli.Contract.Tests.ps1`).
External Windows commands use the adapter in
`tests/fixtures/modules/PrintManagement/`.

## Matrix

| Behavior group | Fixture cases | Test host |
| --- | --- | --- |
| Help | JSON help | PowerShell process |
| Argument errors | Unknown command, unknown option, missing value, extra argument, conflicting option | PowerShell process |
| Printer selection | Missing printer and missing printer-option value | PowerShell process |
| Setup | Success, no printers, missing JSON printer, printer not found, extra argument | PowerShell process with PrintManagement adapter |
| Printer list | All, Universal Print only, empty, list failure, unknown option | PowerShell process with PrintManagement adapter |
| Status | Success, high job count, printer not found, unknown option | PowerShell process with PrintManagement adapter |
| Submission | Universal Print with SumatraPDF, local with Acrobat, local with `PrintTo`, missing file, engine failure, option errors | PowerShell process with PrintManagement and process adapters |
| Queue | Nonempty, empty, cancel one, cancel all, read failure, selector errors, unknown subcommand | PowerShell process with PrintManagement adapter |
| Health | Healthy, unhealthy, unknown option | PowerShell process with PrintManagement and service adapters |
| Configuration | Get, set, default-printer text, unknown key, invalid value, malformed file, unknown subcommand | PowerShell process with isolated user profile |

The contract is the complete fixture index. Contract-document tests require
each referenced path to exist and contain a valid normalized version 1
envelope (`tests/UPrintContract.Tests.ps1`).

## Stable values

- Universal Print printer: `Office UP`
- Local printer: `Local Printer`
- Queue job ID: `7`
- Queue user: `fixture-user`
- Queue submission: `2026-01-02T03:04:05.0000000+00:00`
- Print file: `<file>`
- Envelope timestamp: `<timestamp>`

## Windows acceptance

The adapters make behavior deterministic on a non-Windows test host. Before a
release, repeat these cases on a controlled Windows system:

1. Discover installed printers.
2. Read printer status and queues.
3. Cancel one test job and all jobs on a non-production queue.
4. Run health checks against the Windows Spooler service.
5. Submit through SumatraPDF, Acrobat, and `PrintTo`.
6. Confirm `submitted_to_cloud` for a Universal Print driver.
7. Confirm `submitted` for another installed printer.

These checks confirm integration with Windows. They do not confirm physical
paper output (`CONTEXT.md`, `docs/PRINTING-PRESS-RESEARCH.md`).
