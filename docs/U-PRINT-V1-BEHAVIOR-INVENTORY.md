# U-Print version 1 behavior inventory

## Scope

This inventory describes the current public behavior of `uprint.ps1`. The
PowerShell source and Pester tests are the current authority. The agreed
contract corrections are listed separately.

## Command grammar

The dispatcher currently accepts these command forms:

```text
uprint setup
uprint printers [--universal-only|-u]
uprint status
uprint print <file> [--copies <count>] [--duplex] [--color|--mono]
uprint queue
uprint queue cancel <job-id>
uprint queue cancel --all
uprint health
uprint config
uprint config get
uprint config set <key> <value>
```

The global options are `--json`, `--printer <name>`, and `--help`
(`uprint.ps1:6-11`, `uprint.ps1:73-135`).

The current parser has these differences from the agreed grammar:

- It ignores unknown options.
- It permits `queue cancel` without a job ID or `--all`.
- It permits `--copies` without a value.
- If `--mono` and `--color` occur together, `--color` has precedence.
- It accepts unknown `config` subcommands as configuration reads.
- It accepts and stores unknown configuration keys.
- The first-run guard ignores an explicit `--printer` value.

These behaviors are implementation defects. They are not contract behavior
(`uprint.ps1:64-67`, `uprint.ps1:95-114`, `uprint.ps1:123-135`).

## Defaults

The configuration defaults are:

| Field | Default |
| --- | --- |
| `defaultPrinter` | `null` |
| `autoWake` | `true` |
| `timeout` | `10000` |
| `jsonOutput` | `false` |

Print defaults are one copy, simplex, and color
(`src/lib/Get-UPrintConfig.ps1:6-12`,
`src/commands/Invoke-UPrintPrint.ps1:1-9`).

## JSON envelope

JSON output uses this version 1 envelope:

```json
{
  "version": 1,
  "command": "status",
  "timestamp": "2025-01-15T09:30:00.0000000-08:00",
  "success": true,
  "data": {}
}
```

An error envelope has `error` instead of `data`. A nonempty `warnings` array
is optional. The implementation omits `warnings` when it is empty
(`src/lib/Format-UPrintOutput.ps1:12-30`,
`tests/Format-UPrintOutput.Tests.ps1:7-29`).

The contract requires exactly one JSON envelope on standard output in JSON
mode. Human text from setup, the first-run guard, or malformed configuration
warnings is a current defect (`uprint.ps1:64-67`,
`src/commands/Invoke-UPrintSetup.ps1:7-31`,
`src/lib/Get-UPrintConfig.ps1:14-21`).

## Command result data

### `setup`

Success data has:

- `defaultPrinter`
- `driver`
- `isUP`
- `config`

The command discovers local printers, reads an interactive selection, and
writes `defaultPrinter` to the configuration file
(`src/commands/Invoke-UPrintSetup.ps1:7-53`).

### `printers`

Data has `printers` and `count`. Each printer has:

- `name`
- `type`
- `driver`
- `status`
- `isUP`

The command removes redirected RDP printers. `--universal-only` and `-u`
select only Universal Print printers
(`src/commands/Get-UPrintPrinters.ps1:9-26`).

### `status`

Data has:

- `name`
- `status`
- `driver`
- `port`
- `type`
- `shared`
- `pendingJobs`
- `isUP`

The command adds `High job count: <count> pending` to `warnings` when the job
count is more than five (`src/commands/Get-UPrintStatus.ps1:9-27`).

### `print`

Data has:

- `file`
- `printer`
- `copies`
- `color`
- `duplex`
- `status`
- `engine`

The file value is an absolute path. The option values are requested values.
They do not confirm the values that the engine or printer applied. The
contract does not add a warning for this condition
(`src/commands/Invoke-UPrintPrint.ps1:24-67`).

### `queue`

List data has `jobs`, `count`, and `printer`. Each job has:

- `id`
- `document`
- `status`
- `user`
- `submitted`

A one-job cancellation returns the job ID in `cancelled`. An all-job
cancellation returns the number of removed jobs in `cancelled`. Both forms
also return `printer` (`src/commands/Get-UPrintQueue.ps1:12-41`).

### `health`

Data has `printer`, `healthy`, and `checks`. Each check has `name`, `status`,
and `detail`. Check status values are `PASS`, `FAIL`, `WARN`, `INFO`, and
`SKIP`. Each `FAIL` or `WARN` check also produces one warning string
(`src/commands/Get-UPrintHealth.ps1:7-67`).

### `config`

`config get` returns all four configuration fields. `config set` returns the
resulting configuration. Contract keys are:

- `defaultPrinter`
- `autoWake`
- `timeout`
- `jsonOutput`

Boolean text and unsigned decimal text use the current value coercion rules
(`src/lib/Get-UPrintConfig.ps1:28-53`).

## Public errors

Version 1 contracts these emitted errors:

| Code | Source |
| --- | --- |
| `INVALID_ARGUMENT` | strict dispatcher validation |
| `FILE_NOT_FOUND` | missing print input |
| `PRINT_FAILED` | print submission failure |
| `PRINTER_NOT_FOUND` | status lookup failure |
| `QUEUE_ERROR` | queue read or cancellation failure |
| `NO_PRINTERS` | setup discovery failure |
| `LIST_FAILED` | printer discovery failure |

Each error has `code`, `message`, and nullable `suggestion`. Internal known
errors that no command emits are not public contract values
(`src/lib/New-UPrintError.ps1:1-27` and command catch blocks).

## Exit codes

The contract uses:

| Code | Meaning |
| --- | --- |
| `0` | Success |
| `1` | Operational error |
| `3` | Invalid input, including a missing file |

The current dispatcher enforces these codes only in some paths. Command
errors usually return an error envelope without a nonzero process exit code.
This is a current defect (`README.md:156-158`, `uprint.ps1:59-67`,
`uprint.ps1:87-90`, `uprint.ps1:140-141`).

## Submission and print-engine rules

A submission means that U-Print gave the document to a print engine without
an observed error. It does not confirm physical output.

U-Print identifies Universal Print when the installed driver name contains
`Universal Print`. A Universal Print submission has status
`submitted_to_cloud` and the badge-release warning. Other submissions have
status `submitted` and no badge-release warning
(`src/commands/Invoke-UPrintPrint.ps1:20-22`,
`src/commands/Invoke-UPrintPrint.ps1:59-76`).

The print-engine order is:

1. `tools\SumatraPDF-3.5.2-64.exe`
2. `tools\SumatraPDF.exe`
3. Acrobat
4. Windows `PrintTo`

The order and current option processing must not change
(`src/commands/Invoke-UPrintPrint.ps1:27-56`).

## Side effects and safeguards

- `setup` writes the default printer.
- `config set` writes `%USERPROFILE%\.uprint\config.json`.
- `print` starts one local print engine.
- `queue cancel <job-id>` removes one print job.
- `queue cancel --all` removes all jobs for the selected printer.

A job ID is the safeguard for one-job cancellation. The explicit `--all`
option is the safeguard for all-job cancellation. The contract does not
require confirmation or `--yes`.

## Existing test coverage

Current Pester tests cover the envelope formatter, error builder, printer
listing, printer status, print submission states, queue listing and one-job
cancellation, and health results (`tests/`).

Current tests do not cover the dispatcher, setup, configuration behavior,
strict argument validation, process exit codes, clean JSON standard output,
all-job cancellation, or each print-engine fallback. Normalized fixtures and
process-seam tests must cover these behaviors.
