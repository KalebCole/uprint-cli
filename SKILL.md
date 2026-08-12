---
name: uprint-cli
description: "Print files and operate installed Windows printers with U-Print. Use for printer discovery or selection, status and health checks, queue inspection or cancellation, setup, and print submission."
---

# U-Print

Use U-Print for printers that are already installed in the local Windows
printing system.

## Resolve the CLI

Resolve the entry point once:

```powershell
$uprint = if ($env:UPRINT_CLI_PATH) {
    $env:UPRINT_CLI_PATH
} else {
    $command = Get-Command uprint.ps1 -ErrorAction SilentlyContinue
    if ($command) {
        $command.Source
    } elseif (Test-Path .\uprint.ps1) {
        (Resolve-Path .\uprint.ps1).Path
    }
}

if (-not $uprint -or -not (Test-Path $uprint)) {
    throw 'U-Print was not found. Set UPRINT_CLI_PATH to uprint.ps1.'
}

& $uprint --help --json
```

The help result is the runtime command contract. Use `--json` for every agent
call. A valid call writes exactly one JSON envelope to standard output.

## Select a printer

Printer scope is `installed-printers-only`.

1. When the user does not name a printer, read configuration:

   ```powershell
   & $uprint config get --json
   ```

   Use the configured default when `defaultPrinter` is not null.

2. When no default exists, or the user requests another office or building,
   discover installed printers:

   ```powershell
   & $uprint printers --json
   ```

   Get the user's selection when more than one printer can satisfy the request.
   Pass the selected printer as `--printer <name>` for that call.

3. When the requested printer is absent, stop and report that it must be
   installed in Windows before U-Print can use it. U-Print does not search a
   cloud or building printer directory.

For setup, keep the agent flow noninteractive:

```powershell
& $uprint setup --printer "<name>" --json
```

Plain `setup` is for a human terminal.

## Mutation boundary

Run `print`, `setup`, `config set`, and `queue cancel` only for an explicit
user request.

Prefer cancellation by print job ID:

```powershell
& $uprint queue cancel 42 --printer "<name>" --json
```

Use `queue cancel --all` only when the user explicitly requests cancellation
of all jobs on the selected printer:

```powershell
& $uprint queue cancel --all --printer "<name>" --json
```

## Common operations

Read operations:

```powershell
& $uprint printers --json
& $uprint status --printer "<name>" --json
& $uprint queue --printer "<name>" --json
& $uprint health --printer "<name>" --json
& $uprint config get --json
```

Submit a file:

```powershell
& $uprint print "C:\path\to\file.pdf" --printer "<name>" --json
& $uprint print "C:\path\to\file.pdf" --copies 2 --duplex --mono `
    --printer "<name>" --json
```

Write configuration:

```powershell
& $uprint config set defaultPrinter "<name>" --json
```

Use `& $uprint --help --json` for the complete current grammar and options.

## Interpret the result

Use the process result and envelope together:

- Exit 0: require `success: true`.
- Exit 1: report an operational error from `error.code` and use
  `error.suggestion` when present.
- Exit 3: report invalid input from `error.code` and correct the request before
  another call.

A print submission succeeds only when Exit 0, `success: true`, and
`data.status` is `submitted` or `submitted_to_cloud`.

Call the result a submission. A successful submission does not confirm physical
output. For `submitted_to_cloud`, tell the user that badge release at the
printer may still be required.
