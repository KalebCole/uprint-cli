# U-Print landing page

The landing page is a static site with no build step or runtime dependency:

```text
docs/
  index.html
  styles.css
  rig.js
  README.md
```

Open `index.html` directly, or serve the directory:

```powershell
cd docs
python -m http.server 8000
```

## Product authority

Use `spec/uprint-cli-contract.yaml` as the normative source for commands,
options, configuration, output, errors, and exit codes. Use
`tests/fixtures/*.json` for normalized JSON examples. Do not infer behavior
from old website copy or issue history.

Use the domain terms in `CONTEXT.md`:

- A submission transfers a document to a print engine without an observed
  error.
- A Universal Print submission reports `submitted_to_cloud`.
- Another printer submission reports `submitted`.
- Neither status confirms that paper came out.

The interactive rig can illustrate the downstream badge and paper path, but
its CLI observation must stop at `submitted_to_cloud`.

## Verification

Run the focused website contract test:

```powershell
Import-Module Pester -RequiredVersion 5.7.1
Invoke-Pester tests/UPrintWebsite.Tests.ps1 -Output Detailed
```

Then run the complete test suite:

```powershell
Import-Module Pester -RequiredVersion 5.7.1
Invoke-Pester tests/ -Output Detailed
```

After UI edits, run the detector once:

```powershell
node /home/azureuser/.agents/skills/impeccable/scripts/detect.mjs --json docs/index.html docs/styles.css docs/rig.js
```

Inspect the page at desktop and mobile widths. Check command overflow, tables,
copy buttons, keyboard focus, reduced motion, and 200% zoom.

## Publishing

GitHub Pages serves this repository from `master:/docs` at
<https://kalebcole.github.io/uprint-cli/>.

Push the verified change to `master`, then confirm the Pages build:

```powershell
gh api repos/KalebCole/uprint-cli/pages --jq '{status: .status, source: .source}'
```

When the status is `built`, check the live page for the current PowerShell
setup command and confirm that obsolete JavaScript-runtime instructions are
absent.
