# `docs/` — the uprint landing page

Three files, no build step, no framework, no package manifest.

```
docs/
  index.html    markup + the design contract, as a header comment
  styles.css    the whole visual system
  rig.js        the FIG. 1 animation and the copy buttons
```

Open `index.html` directly in a browser, or serve the folder:

```powershell
cd docs
python -m http.server 8000
```

## Publishing

> **Merging this into `kalebcole_microsoft/uprint-cli` does not make the page
> live.** It is not a deploy. The publish step is a separate manual copy into a
> different repo, tracked as **issue #43**. Read this section before assuming it
> shipped.

There are **two repositories**, and they share no git history:

| | repo | Pages | `docs/` |
|---|---|---|---|
| work | `kalebcole_microsoft/uprint-cli` | none, and cannot have it | added by this change |
| public | `KalebCole/uprint-cli` | enabled, built, live | already there, currently served |

The public one is **not a fork** (`fork: false`, `parent: none`) and has
independent lineage. The work repo's `master` commit does not exist in it at all
— asking the API for it returns HTTP 422, no commit found. So the two cannot be
merged, rebased, or cherry-picked between. Moving a change from one to the other
is a **file copy plus a fresh commit**.

The work repo can never publish. `kalebcole_microsoft` is an Enterprise Managed
User account: EMU accounts can only own private repositories, and EMU Pages can
only publish from organization-owned repos and are always privately published.
That is enterprise policy, not a billing tier. No plan upgrade changes it.

### To actually publish

Tracked as **issue #43**. It cannot be done from this repo by any agent or
automation working here:

```
gh api repos/KalebCole/uprint-cli --jq .permissions
{"admin":false,"maintain":false,"push":false,"pull":true,"triage":false}
```

The identity available in this repo is `kalebcole_microsoft`; the public repo is
owned by the personal `KalebCole` account, which it has read access to and
nothing more. This is a step a human with that account has to take.

Copy these four files into `KalebCole/uprint-cli` at `master:/docs`, which is
what Pages serves, and commit there:

```
docs/index.html
docs/styles.css
docs/rig.js
docs/README.md
```

Only the first is a replacement; the other three are new. That replaces the page
currently live at <https://kalebcole.github.io/uprint-cli/>, which is serving
unmeasured metrics (see *Editing rules* below). Until that copy happens, the
wrong page stays up, publicly and indexably.

### Why the clone command on the page is still correct

The page tells visitors to clone `github.com/kalebcole/uprint-cli`, so that
repo's code is what they get, not this one's. Comparing the two trees by blob
SHA:

```
public: 23 files    work: 22 files
only in public : docs/index.html
only in work   : (none)
differing      : (none)
```

The public repo is **exactly this repo's `master` plus a landing page**. Every
file matches by hash, so every command, flag, exit code and envelope field
documented on the page is accurate against the repo the page sends people to,
and adding the four files above is provably safe.

That is a coincidence of content, not a guarantee of lineage. The histories are
unrelated, nothing keeps them in step, and this is the fact most likely to stop
being true first. If they diverge, the command reference has to be re-verified
against the **public** repo, not this one.

### No GitHub Actions workflow, deliberately

There is nothing to build, Pages is already wired to a branch in the repo that
publishes, and a workflow here could never succeed. It would only post a red
check on every unrelated push.

## Editing rules

**Never state a number you cannot source.** An earlier version of this page
published "95% time reduction", "41s avg print-to-paper", "13+ min before" and
"0 coworkers bothered". None of them came from a measurement. They are gone and
should not come back.

**Verify against code, not the README.** Every command, flag, exit code and
envelope field on this page was read out of `uprint.ps1` and `src/`. The README
is incomplete in places — it omits `--universal-only`, and the per-command
`print` flags — and the page corrects it rather than copying it.

**Verifying the tokens in a claim is not the same as verifying the claim.** The
rule above passed on a technicality once, and it is worth knowing how. The page
originally said exit `1` meant "general error", with the values `0`/`1`/`3`
correctly checked against `uprint.ps1`. The values were right. The word
"general" was wrong, `1` fires only for an unknown command, and that word came
from `README.md:159` rather than from the code. Checking the identifiers in a
sentence while inheriting its meaning from prose is not verification. Tracked as
issue #46, since the same compressed table is restated in four places.

**Never say "printed".** The tool cannot currently observe whether paper came
out, so the page never claims it did. The literal value matters: on a Universal
Print target the envelope reports `submitted_to_cloud`, and only on a
non-Universal-Print target does it report plain `submitted`
(`Invoke-UPrintPrint.ps1` line 59). Universal Print is the flagship path, so an
agent that hardcodes `status === 'submitted'` fails on exactly the printers this
tool exists for. Show both values, never just one.

**No deep issue links.** Issue numbers differ between the private work repo and
the public mirror this page is served from, so `/issues/34` would 404 for every
visitor. State limitations in prose; link the tracker at the top level only.

## Unshipped commands

Two strings on the page describe things that do not exist yet. Both are marked
so they are a one-place edit:

| Attribute | Waiting on |
|---|---|
| `data-release-key="npm"` | the TypeScript port, which brings an `npm install -g` route |
| `data-release-key="skill"` | `uprint skill install` |

When either lands, find the attribute, update the copy, and flip
`data-release="pending"` to `"shipped"`. There is a `<!-- RELEASE STRINGS -->`
block near the top of `index.html` saying the same thing in place.

### One open issue is not a string flip

**Issue #29 made JSON the default output, and it has landed.** This page's
framing inverted with it: it used to present the tool as human-readable by
default with `--json` as the opt-in for agents. JSON is now the default and
`--human` is the opt-out. All three of the things this section used to list
as going stale have been updated:

- the global flags list now leads with `--human` and records `--json` as
  accepted but a no-op
- the `jsonOutput` config row now documents unset as meaning JSON, with
  `false` as the permanent human opt-out — and notes that `config get` still
  reports `false` for an unset key, which is deliberate PowerShell parity and
  pinned by a test, not a bug
- the `--json` in the FIG. 1 stdout label and the sample commands is gone,
  having become redundant rather than wrong

The warning worth keeping past the issue it was written for: check the flag's
real behaviour before editing, not the issue title. `uprint.ps1` no longer
exists — the TypeScript port replaced it — which is itself an example of the
point. An issue being open is not evidence about what the code does, and
neither is an issue being closed.

### The exit-code copy is doomed in the other direction

**Issue #35, the TypeScript port, falsifies copy that is correct today.** On
`master` there is no `exit` statement anywhere in `src/`, so a handled error
emits `success:false` and the process still exits `0`; only an unknown command
exits `1`. The page says exactly that, in the *Success is the signal* contract
item and the exit-code list. It is right, and it is about to stop being right:
`src/lib/render.ts` on the port branch maps any errored result to `1` with no
mode parameter.

This is the harder class to catch. The `data-release` markers only flag copy
that is *already* false, so they are structurally blind to copy that is accurate
now and breaks on merge. **A claim can be true, unmarked, and doomed at the same
time.** The only check that finds these is reading the branch about to land, not
just `master`.

### A sibling of this note lives in the skill package

`skills/uprint/references/` carries its own release-sensitive claims about the
same surface. `json-schema.md:34` says "Check `success`, not the exit code &mdash;
a handled error is returned as an envelope and the process still exits `0`",
which is the same conclusion this page reached by a different route, and is
exposed to #35 the same way. `troubleshooting.md`
documents a workaround for a trap the port removes. Neither file is discoverable
from this one and neither knows the other exists. **If you update
release-sensitive copy here, check there too**, and vice versa. They describe the
same CLI and will rot on the same merges.

## The FIG. 1 rig

The hero animation is not decoration — it is the product's actual sequence, and
the timing is the argument. Nothing inside the machine moves until the badge
taps the reader, because Universal Print really does hold the job in the cloud
until release at the device. `Invoke-UPrintPrint.ps1` returns
`status: "submitted_to_cloud"` with the warning *"Universal Print: job held in
cloud until badge release at printer"*, and the rig shows exactly that: amber
LED and a stalled paper path until the badge lands.

If you change the animation, keep that beat. A rig where paper moves
immediately on submit would be a prettier lie.

`prefers-reduced-motion` short-circuits to the finished state with the same
text output.
