# uprint-cli

Universal Print CLI for humans and AI agents. List printers, check status, print files, manage the print queue, and run health diagnostics — all from the command line. Designed for both human operators and AI agents (Copilot CLI, Claude, etc.) with structured JSON output.

## Quick Start

```powershell
# Clone the repo
git clone <repo-url>
cd uprint-cli

# Run interactive setup to discover and select your default printer
.\uprint.ps1 setup

# Print a file
.\uprint.ps1 print report.pdf

# Check printer status (JSON output for agents)
.\uprint.ps1 status --json
```

## Requirements

- Windows 10/11 with Print Management (built-in)
- PowerShell 5.1+ or PowerShell 7+

For tests:

- PowerShell 7
- [Pester 5.7.1](https://pester.dev)
- [powershell-yaml](https://github.com/cloudbase/powershell-yaml)

The CLI has no additional runtime dependencies. It uses built-in Windows Print
Management cmdlets.

## Commands

| Command | Description |
|---------|-------------|
| `uprint setup` | Interactive printer discovery and default selection |
| `uprint printers` | List available printers |
| `uprint status` | Show printer status (online/offline, queue depth) |
| `uprint print <file>` | Print a file |
| `uprint queue` | List pending print jobs |
| `uprint queue cancel <id>` | Cancel a specific print job |
| `uprint queue cancel --all` | Cancel all print jobs |
| `uprint health` | Run diagnostic health check |
| `uprint config get` | Show all configuration |
| `uprint config set <key> <value>` | Set configuration value |

### Global Flags

| Flag | Description |
|------|-------------|
| `--json` | Structured JSON output (agent-friendly) |
| `--printer <name>` | Target a specific printer |
| `--help` | Show help text |

### Examples

```powershell
# Setup (first run)
.\uprint.ps1 setup

# List all printers
.\uprint.ps1 printers --json

# Print with options
.\uprint.ps1 print slides.pdf --printer Office-Printer-2 --copies 2 --duplex

# View and manage queue
.\uprint.ps1 queue --json
.\uprint.ps1 queue cancel --all

# Health diagnostics
.\uprint.ps1 health --json

# Configuration
.\uprint.ps1 config set defaultPrinter "Office-Printer-1"
.\uprint.ps1 config set jsonOutput true
```

## JSON Output Format

All commands support `--json` for structured output. The envelope schema:

```json
{
  "version": 1,
  "command": "status",
  "timestamp": "2025-01-15T09:30:00.0000000-08:00",
  "success": true,
  "data": { ... }
}
```

On error:

```json
{
  "version": 1,
  "command": "print",
  "timestamp": "2025-01-15T09:30:00.0000000-08:00",
  "success": false,
  "error": {
    "code": "FILE_NOT_FOUND",
    "message": "File to print was not found"
  }
}
```

Optional `warnings` array is included when applicable.

## Agent Integration

### Copilot CLI

```powershell
Copy-Item ".\SKILL.md" "$env:USERPROFILE\.copilot\skills\uprint-cli.skill.md"
```

Once installed, Copilot CLI will automatically invoke uprint when you mention printing, printers, or print queue in conversation.

### Other AI Agents

Add to your agent instructions:

```
For printing tasks, use the uprint CLI at .\uprint.ps1.
Always pass --json for structured output. See SKILL.md for full command reference.
```

## Architecture

```
uprint-cli/
├── uprint.ps1                  # Entry point / dispatcher
├── src/
│   ├── commands/               # One script per command
│   │   ├── Get-UPrintPrinters.ps1
│   │   ├── Get-UPrintStatus.ps1
│   │   ├── Invoke-UPrintPrint.ps1
│   │   ├── Get-UPrintQueue.ps1
│   │   ├── Get-UPrintHealth.ps1
│   │   └── Invoke-UPrintSetup.ps1
│   └── lib/                    # Shared helpers
│       ├── Format-UPrintOutput.ps1   # JSON envelope formatter
│       ├── New-UPrintError.ps1       # Structured error builder
│       └── Get-UPrintConfig.ps1      # Config read/write
├── tests/                      # Pester unit tests (one per command)
├── SKILL.md                    # Copilot CLI skill definition
├── LICENSE                     # MIT License
└── README.md
```

**Dispatcher pattern:** `uprint.ps1` parses arguments, sources library helpers, and routes to the appropriate command script via a `switch` block. Each command script is self-contained and returns data through `Format-UPrintOutput`, which wraps results in a consistent JSON envelope or human-readable text.

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 3 | Invalid input (bad arguments, missing file) |

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/my-feature`)
3. Run tests:
   `Import-Module Pester -RequiredVersion 5.7.1; Invoke-Pester tests/ -Output Detailed`
4. Commit with [conventional commits](https://www.conventionalcommits.org/)
5. Open a pull request

## License

[MIT](LICENSE)
