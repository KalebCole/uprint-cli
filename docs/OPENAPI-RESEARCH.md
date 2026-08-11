# OpenAPI feasibility

## Conclusion

The repository cannot accurately publish an OpenAPI document for its current
interface. OpenAPI describes HTTP APIs, while `uprint` is a local PowerShell CLI
that dispatches arguments, invokes Windows print-management commands, and writes
results to stdout. It has no HTTP server, routes, request authentication, or
HTTP status model.

If an HTTP interface is a product goal, define and implement either a
Windows-hosted HTTP facade over the local print spooler or a service backed by
Microsoft Graph Universal Print. Write the OpenAPI contract alongside that
design; publishing one before choosing the architecture would document behavior
that does not exist.

## Current architecture

The current implementation:

- discovers printers with `Get-Printer`;
- reads and cancels local jobs with `Get-PrintJob` and `Remove-PrintJob`;
- submits documents through SumatraPDF, Acrobat, or the Windows `PrintTo` verb;
- identifies Universal Print printers by matching the installed driver's name;
- exposes a CLI and JSON stdout envelope, not network endpoints.

Microsoft documents the PrintManagement cmdlets as operations on printers and
print jobs installed on a computer:

- [Get-Printer](https://learn.microsoft.com/en-us/powershell/module/printmanagement/get-printer?view=windowsserver2025-ps)
- [Get-PrintJob](https://learn.microsoft.com/en-us/powershell/module/printmanagement/get-printjob?view=windowsserver2025-ps)
- [Remove-PrintJob](https://learn.microsoft.com/en-us/powershell/module/printmanagement/remove-printjob?view=windowsserver2025-ps)

The [OpenAPI Specification](https://spec.openapis.org/oas/v3.1.1.html) defines
an interface description for HTTP APIs, so it cannot directly describe CLI
arguments and stdout behavior.

## Existing Universal Print HTTP API

Microsoft Graph already provides HTTP resources for the Universal Print subset,
including:

- [list printers](https://learn.microsoft.com/en-us/graph/api/print-list-printers?view=graph-rest-1.0);
- [list a printer's jobs](https://learn.microsoft.com/en-us/graph/api/printer-list-jobs?view=graph-rest-1.0);
- [create a print job](https://learn.microsoft.com/en-us/graph/api/printer-post-jobs?view=graph-rest-1.0);
- [create a document upload session](https://learn.microsoft.com/en-us/graph/api/printdocument-createuploadsession?view=graph-rest-1.0);
- [cancel a print job](https://learn.microsoft.com/en-us/graph/api/printjob-cancel?view=graph-rest-1.0).

That API is not a drop-in description of this CLI. The CLI works with all
locally installed printers and submits through local applications; it does not
call Microsoft Graph.

## Possible local HTTP facade

A local-device API could use this resource model:

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/v1/printers?universalOnly=true` | List installed printers |
| `GET` | `/v1/printers/{printerId}` | Read printer state |
| `GET` | `/v1/printers/{printerId}/health` | Run printer diagnostics |
| `GET` | `/v1/printers/{printerId}/jobs` | List queued jobs |
| `POST` | `/v1/printers/{printerId}/jobs` | Upload and submit a document |
| `GET` | `/v1/printers/{printerId}/jobs/{jobId}` | Read a queued job |
| `DELETE` | `/v1/printers/{printerId}/jobs/{jobId}` | Cancel a queued job |

`POST` should accept a multipart document plus explicit `copies`, `colorMode`,
and `duplex` fields, then return `202 Accepted` and a job resource. It should
not accept arbitrary server-side filesystem paths. Setup and configuration
should remain administrative and out of band because the current setup flow is
interactive.

The facade would also require:

- a Windows-hosted HTTP listener and routing layer;
- request and upload validation;
- stable, opaque printer and job identifiers;
- noninteractive configuration;
- temporary upload storage or streaming;
- an adapter around the current spooler operations;
- explicit HTTP error and asynchronous job-state semantics.

Submission must be modeled as accepted or submitted, not physically printed.
The implementation cannot observe paper output and reports
`submitted_to_cloud` for Universal Print targets.

## Security requirements

Bind to loopback by default. Remote access should require TLS, authenticated
callers, per-printer authorization, separate read/submit/cancel privileges,
upload size and rate limits, media-type validation, malware scanning, and an
audit trail. Logs must exclude document contents, local file paths, bearer
tokens, and upload URLs.

For a Graph-backed design, use delegated least-privilege permissions. The
official endpoint documentation lists permissions such as `Printer.Read.All`,
`PrintJob.Create`, `PrintJob.ReadBasic`, and `PrintJob.ReadWriteBasic`.
Cancellation is delegated-only, and cancelling another user's job requires the
Printer Administrator role.

## Recommendation

1. Use Microsoft Graph directly if the intended scope is tenant-managed
   Universal Print.
2. Build a Windows-local HTTP agent only if callers must also control locally
   installed non-Universal printers.
3. Do not add an OpenAPI file for the current CLI. First choose one of those
   architectures and define its authentication, upload lifecycle, identifiers,
   errors, and job-state semantics; then make the OpenAPI contract part of the
   implementation.
