# Printing Press workflow assessment

## Recommendation

Use [CLI Printing Press](https://github.com/mvanhorn/cli-printing-press) as an
adapted product and quality workflow, not as uprint's generator or publishing
pipeline.

Printing Press primarily generates Go CLIs from HTTP API descriptions, HAR
captures, browser discovery, or its BLE-specific device workflow. Uprint is a
PowerShell dispatcher over locally installed Windows printers, the Windows
spooler, and local print applications. Its current implementation must remain
the behavioral authority.

Relevant primary sources:

- [Printing Press main skill](https://github.com/mvanhorn/cli-printing-press/blob/main/skills/printing-press/SKILL.md)
- [Printing Press concepts](https://github.com/mvanhorn/cli-printing-press/blob/main/CONCEPTS.md)
- [Printing Press README](https://github.com/mvanhorn/cli-printing-press/blob/main/README.md)
- [Microsoft Get-Printer](https://learn.microsoft.com/en-us/powershell/module/printmanagement/get-printer?view=windowsserver2025-ps)
- [Microsoft Get-PrintJob](https://learn.microsoft.com/en-us/powershell/module/printmanagement/get-printjob?view=windowsserver2025-ps)
- [Microsoft Remove-PrintJob](https://learn.microsoft.com/en-us/powershell/module/printmanagement/remove-printjob?view=windowsserver2025-ps)

## Architecture mismatch

| Concern | Printing Press default | Uprint reality |
| --- | --- | --- |
| Runtime | Generated Go/Cobra CLI and MCP server | PowerShell dispatcher and sourced command scripts |
| Contract | HTTP/OpenAPI, HAR, browser capture, or BLE device spec | PrintManagement cmdlets, spooler, and local applications |
| Submission | HTTP API request | SumatraPDF, Acrobat, or Windows `PrintTo` |
| Success | API response and optional live verification | Job submission; physical output cannot be observed |
| Tests | Go build/vet and Press verification | Pester with mocked cmdlets and process launching |
| Publishing | Printing Press Library import/publish process | Uprint's own repository and release process |

The current `print` command intentionally returns `submitted_to_cloud` for a
Universal Print driver and `submitted` otherwise. It does not claim that paper
was produced. This behavior and the SumatraPDF, Acrobat, then `PrintTo`
fallback order must be preserved.

See:

- [`uprint.ps1`](../uprint.ps1)
- [`Invoke-UPrintPrint.ps1`](../src/commands/Invoke-UPrintPrint.ps1)
- [Microsoft Start-Process](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/start-process?view=powershell-7.5)

## Source-of-truth contract

Uprint does not need OpenAPI. The
[OpenAPI Specification](https://spec.openapis.org/oas/v3.1.1.html#what-is-the-openapi-specification)
describes HTTP APIs, not local CLI arguments, stdout, spooler state, or
PowerShell process invocation.

Printing Press permits inputs other than OpenAPI, including device
specifications, but its implemented device workflow is BLE-specific:

- [Printing Press concepts](https://github.com/mvanhorn/cli-printing-press/blob/main/CONCEPTS.md)
- [BLE device workflow](https://github.com/mvanhorn/cli-printing-press/blob/main/skills/printing-press/references/device-sniff-ble.md)

Create a project-native, versioned `spec/uprint-cli-contract.yaml`, explicitly
not an OpenAPI document. Until it exists, the PowerShell source and Pester tests
remain authoritative.

The contract should define:

- Windows, PowerShell, PrintManagement, and print-engine prerequisites;
- command grammar, flags, defaults, and destructive-operation safeguards;
- JSON envelope version 1, command-specific data, warnings, and errors;
- actual process exit behavior;
- printer and spooler interactions;
- Universal Print detection and submission semantics;
- SumatraPDF, Acrobat, and `PrintTo` fallback precedence;
- compatibility fixtures for JSON and human output.

[Pester](https://pester.dev/docs/quick-start) supports the unit, integration,
and mock-based tests needed to enforce this contract.

## Skill-by-skill assessment

| Skill | Recommendation |
| --- | --- |
| [`printing-press`](https://github.com/mvanhorn/cli-printing-press/blob/main/skills/printing-press/SKILL.md) | Adapt its brief, scoped feature manifest, implementation, and shipcheck sequence. Exclude API discovery, generated Go, MCP, and SQLite assumptions. |
| [`printing-press-polish`](https://github.com/mvanhorn/cli-printing-press/blob/main/skills/printing-press-polish/SKILL.md) | Adapt its baseline, diagnose, fix, and re-diagnose loop. Replace Go and Press gates with Pester, PowerShell checks, contract validation, and controlled Windows integration tests. |
| [`printing-press-output-review`](https://github.com/mvanhorn/cli-printing-press/blob/main/skills/printing-press-output-review/SKILL.md) | Use optionally against captured JSON and human-output fixtures. Do not run unchanged because it expects Press scorecards and generated artifacts. |
| [`printing-press-score`](https://github.com/mvanhorn/cli-printing-press/blob/main/skills/printing-press-score/SKILL.md) | Adapt optionally into a uprint scorecard for compatibility, safety, diagnostics, JSON stability, and Windows integration coverage. |
| [`printing-press-reprint`](https://github.com/mvanhorn/cli-printing-press/blob/main/skills/printing-press-reprint/SKILL.md) | Reuse the concept for a major redesign: carry forward the contract, fixtures, tests, and research. Do not use its generated-tree merge flow unchanged. |
| [`printing-press-amend`](https://github.com/mvanhorn/cli-printing-press/blob/main/skills/printing-press-amend/SKILL.md) | Reuse only the scope and planning ideas. Its managed library clone, transcript, patch-manifest, and PR workflow do not fit this repository. |
| [`printing-press-retro`](https://github.com/mvanhorn/cli-printing-press/blob/main/skills/printing-press-retro/SKILL.md) | Use optionally after substantial changes, without uploading artifacts or modifying Printing Press itself. |
| [`printing-press-import`](https://github.com/mvanhorn/cli-printing-press/blob/main/skills/printing-press-import/SKILL.md) | Do not use. It imports generated Go CLIs and rewrites module paths. |
| [`printing-press-publish`](https://github.com/mvanhorn/cli-printing-press/blob/main/skills/printing-press-publish/SKILL.md) | Do not use. It packages and publishes generated Go projects through the Printing Press Library. |

## Recommended workflow

1. **Capture compatibility:** derive the contract and a complete command,
   flag, exit, and output matrix from source and tests.
2. **Write an adapted research brief:** record official Windows cmdlet
   behavior, supported print engines, and the boundary between submitted and
   physically printed.
3. **Define workflows:** setup, list/filter printers, status, submit, queue
   list/cancel, and health. Classify cancellation, especially `--all`, as
   destructive.
4. **Implement PowerShell-first:** evolve the existing dispatcher, commands,
   and libraries rather than generating an unrelated Go/MCP application.
5. **Run an adapted shipcheck:** Pester, script-loading checks, contract/schema
   validation, golden output fixtures, and controlled tests against a
   non-production Windows printer.
6. **Review outputs:** cover JSON and human modes, Universal Print warnings,
   empty queues, missing printers/files, and cancellation results.
7. **Release through uprint:** do not use Printing Press import or publish.
   Run a short retro after major changes.

## Compatibility gates

Do not merge a generated or rewritten CLI until tests prove:

- command names and positional grammar are unchanged;
- global, printer, print, and queue flags retain their behavior;
- the JSON envelope and established error codes remain compatible;
- Universal Print detection still yields `submitted_to_cloud`;
- non-Universal targets still yield `submitted`;
- print-engine fallback order is preserved;
- fast mocked tests and controlled Windows integration tests pass;
- no output claims that a document physically printed.

Where prose and implementation disagree, source and tests take precedence. The
repository's [`docs/README.md`](README.md) already records examples of
documentation lagging actual behavior.
