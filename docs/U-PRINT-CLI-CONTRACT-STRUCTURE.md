# U-Print CLI contract YAML structure

## Decision

Use one project-specific YAML file at `spec/uprint-cli-contract.yaml`. This
file is a CLI and local-device contract. It is not an OpenAPI document
(`docs/OPENAPI-RESEARCH.md`, `docs/PRINTING-PRESS-RESEARCH.md`).

Use JSON Schema type words inside the YAML file. These words make data shapes
precise without a second schema file:

- `type`
- `properties`
- `required`
- `additionalProperties`
- `items`
- `enum`
- `const`
- `oneOf`

Keep `contractVersion` separate from JSON envelope `version`. The contract
version identifies this document. Envelope version `1` identifies the public
JSON format (`src/lib/Format-UPrintOutput.ps1:12-18`).

## Required top-level fields

```yaml
kind: uprint-cli-contract
contractVersion: 1
platform: {}
configuration: {}
globalOptions: {}
jsonEnvelope: {}
errors: {}
exitCodes: {}
commands: {}
printSubmission: {}
fixtures: []
```

Each top-level field has one purpose:

| Field | Purpose |
| --- | --- |
| `kind` | Identifies the project-specific document type. |
| `contractVersion` | Identifies the contract structure version. |
| `platform` | Defines Windows, PowerShell, and PrintManagement requirements. |
| `configuration` | Defines configuration fields, defaults, and coercion. |
| `globalOptions` | Defines options that apply to command dispatch. |
| `jsonEnvelope` | Defines the common version 1 JSON result. |
| `errors` | Defines the public error shape and emitted error codes. |
| `exitCodes` | Defines process result codes. |
| `commands` | Defines grammar, data, warnings, and side effects. |
| `printSubmission` | Defines detection, status, and engine order. |
| `fixtures` | Links normalized acceptance examples to contract cases. |

## Command structure

Each command definition must include:

```yaml
commands:
  example:
    grammar: uprint example <value>
    positionals: {}
    options: {}
    output:
      data: {}
      warnings: []
    errors: []
    sideEffects: []
```

Use separate variants when one command name has different data or side
effects. For example, `queue list`, `queue cancel <job-id>`, and
`queue cancel --all` are separate variants behind the `queue` command
(`src/commands/Get-UPrintQueue.ps1:12-45`).

Each positional argument and option must define:

- accepted spelling
- type
- required state
- default, when applicable
- value limit, when applicable
- mutual exclusion, when applicable

The grammar must reject unknown options, missing values, conflicting options,
and incomplete subcommands.

## JSON envelope structure

The contract must define success and error as two exclusive envelope variants:

```yaml
jsonEnvelope:
  version: 1
  success:
    type: object
    required: [version, command, timestamp, success, data]
    additionalProperties: false
  error:
    type: object
    required: [version, command, timestamp, success, error]
    additionalProperties: false
```

Both variants require `version`, `command`, `timestamp`, and `success`.
Success requires `data` and excludes `error`. Failure requires `error` and
excludes `data`. A nonempty `warnings` array is optional
(`src/lib/Format-UPrintOutput.ps1:12-30`).

JSON mode must write exactly one envelope to standard output. It must not
write human messages to standard output. Human output remains available, but
its exact text is not part of this contract.

## Data structures

Put reusable command data shapes under the command that owns them. Do not
create a general schema registry for seven commands. This keeps the contract
local and reduces references.

Every object shape must define:

- `type: object`
- `required`
- `additionalProperties`
- `properties`

Every array shape must define `items`. Every fixed vocabulary must use
`enum`. Fixed envelope and contract values must use `const`.

## Error and exit structures

Define one common error object with `code`, `message`, and nullable
`suggestion`. Define only codes that a version 1 command can emit.

Define process exit codes as normative behavior:

```yaml
exitCodes:
  0: success
  1: operational-error
  3: invalid-input
```

A missing print file is invalid input. Current zero-exit error paths are
implementation defects, not contract behavior.

## Side effects and safeguards

Each command variant must list its state reads and state changes. Cancellation
definitions must state:

- one-job cancellation requires a positive job ID
- all-job cancellation requires the exact `--all` option
- job ID and `--all` are mutually exclusive
- no confirmation prompt or `--yes` option is required

## Submission structure

`printSubmission` must define:

- Universal Print detection by installed driver-name match
- `submitted_to_cloud` for Universal Print
- `submitted` for other printers
- no confirmation of physical output
- SumatraPDF, Acrobat, and `PrintTo` engine order
- current option processing for each engine

Use the terms in `CONTEXT.md`. Do not use `printed` as a successful state.

## Fixture structure

Each fixture reference must identify one behavior:

```yaml
fixtures:
  - id: status.success
    command: status
    case: success
    path: tests/fixtures/status.success.json
```

Use normalized JSON fixtures for distinct behavior branches. Replace
timestamps, machine paths, user names, printer names, and job identifiers
with stable example values. Do not add exact human-output fixtures.

## Validation

Use Pester to validate:

1. The contract has every required top-level field.
2. Each command has complete grammar and result definitions.
3. Each referenced fixture exists.
4. Each fixture matches the command data shape and common envelope.
5. The PowerShell process produces the specified JSON and exit code.

Do not add a new contract tool unless Pester cannot perform a required check.
