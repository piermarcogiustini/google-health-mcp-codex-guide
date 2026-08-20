# Google Health MCP Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a safe Windows installer and bilingual guide that prepare Google Health MCP locally and explain how to connect it to ChatGPT Desktop, Claude Desktop, Codex, and Claude Code.

**Architecture:** A single PowerShell entry point checks prerequisites, invokes a pinned upstream MCP package for setup, OAuth, and live diagnosis, and never edits client configuration or captures secrets. A dependency-free PowerShell test harness validates parsing, command construction, scope selection, failure propagation, and dry-run behavior. Complete Italian and English READMEs explain Google Cloud OAuth and the four manual client connection paths.

**Tech Stack:** Windows PowerShell 5.1-compatible PowerShell, Node.js and `npx`, Google Health MCP upstream package, Markdown, Git.

**Spec:** `docs/superpowers/specs/2026-08-20-google-health-mcp-installer-design.md`

## Global Constraints

- Version 1 provides an automatic installer only for Windows.
- The installer must not edit ChatGPT, Claude, Codex, or Claude Code configuration files.
- The installer must not accept credentials as command-line arguments or print, log, or persist credentials, authorization codes, tokens, or health records.
- The upstream package version must be verified before it is pinned; the previously proven compatibility baseline is `google-health-mcp-unofficial@0.7.6`.
- The default scope set is minimal read-only; ECG, irregular-rhythm notifications, and exercise GPS are an explicit extended read-only choice.
- The recommended upstream privacy mode is `structured`.
- The English and Italian guides must be functionally equivalent and use identical commands.
- The repository stays private until implementation, live validation, secret scanning, bilingual review, and separate user approval are complete.
- The PIERMARCO / LOG article is a separate follow-up subsystem and is not implemented by this plan.

## File Map

- `install.ps1`: Windows installer, pure helper functions, interactive entry point, dry-run mode, and upstream command orchestration.
- `tests/install.tests.ps1`: dependency-free unit/integration-style test harness that dot-sources the installer and injects a fake external-command runner.
- `README.it.md`: canonical Italian setup narrative based on the proven user journey.
- `README.md`: adapted English equivalent and GitHub landing page.
- `.gitignore`: excludes local secrets, tokens, logs, environment files, and generated test output.
- `LICENSE`: MIT license for this repository's original installer and documentation.
- `docs/superpowers/specs/2026-08-20-google-health-mcp-installer-design.md`: approved design source.
- `docs/superpowers/plans/2026-08-20-google-health-mcp-installer.md`: this execution plan.

---

### Task 1: Verify and record the upstream contract

**Files:**
- Modify: `docs/superpowers/plans/2026-08-20-google-health-mcp-installer.md`
- Reference: `docs/superpowers/specs/2026-08-20-google-health-mcp-installer-design.md`

**Interfaces:**
- Consumes: the proven package baseline and commands from the approved design.
- Produces: an evidence-backed package name, exact version, minimum Node major version, supported setup/auth/doctor arguments, privacy choices, callback URI, scope environment variable, and upstream license for Tasks 2-6.

- [ ] **Step 1: Read current primary sources**

Open the current upstream repository, npm package metadata, Google Health setup/scopes documentation, OpenAI MCP documentation, and Anthropic MCP documentation. Record source URLs in working notes; do not copy personal setup data.

- [ ] **Step 2: Query the exact npm package contract**

Run:

```powershell
npm.cmd view google-health-mcp-unofficial version engines license repository --json
npx.cmd -y google-health-mcp-unofficial@0.7.6 --help
npx.cmd -y google-health-mcp-unofficial@0.7.6 setup --help
npx.cmd -y google-health-mcp-unofficial@0.7.6 doctor --help
```

Expected: package metadata resolves; help output confirms the supported command names and flags without starting OAuth or reading health data.

- [ ] **Step 3: Inspect the upstream license and security-sensitive behavior**

Confirm from the upstream source that credentials and tokens are stored outside the future repository, determine the exact local callback URI, and verify how `GOOGLE_HEALTH_SCOPES` and privacy mode are consumed. Do not display any existing local credential file.

- [ ] **Step 4: Resolve the pinned constants**

Choose the newest version only if its documented contract matches the proven flow. Otherwise retain `0.7.6`. Record these exact implementation constants in the task notes:

```text
PackageName
PackageVersion
MinimumNodeMajor
CallbackUri
SetupArguments
AuthArguments
DoctorArguments
StandardReadOnlyScopes
ExtendedReadOnlyScopes
```

- [ ] **Step 5: Stop on incompatibility**

If current upstream behavior no longer supports local setup, OAuth, `structured` privacy, or live diagnosis, stop implementation and report the precise incompatibility instead of designing undocumented flags.

---

### Task 2: Build the tested installer core

**Files:**
- Create: `install.ps1`
- Create: `tests/install.tests.ps1`

**Interfaces:**
- Consumes: exact constants verified in Task 1.
- Produces: `Get-NodeMajorVersion`, `Get-GoogleHealthScopeSet`, `Get-UpstreamCommandPlan`, `Test-InstallerPrerequisites`, `Invoke-ExternalStep`, and `Invoke-GoogleHealthMcpInstaller`.

- [ ] **Step 1: Write the first failing tests**

Create `tests/install.tests.ps1` with a tiny assertion harness and these initial cases:

```powershell
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\install.ps1') -LibraryMode

$failures = 0
function Assert-Equal($Expected, $Actual, [string]$Name) {
  if ($Expected -ne $Actual) {
    $script:failures++
    Write-Error "$Name expected '$Expected' but received '$Actual'" -ErrorAction Continue
  }
}

Assert-Equal 24 (Get-NodeMajorVersion 'v24.18.1') 'parses current Node output'
Assert-Equal 18 (Get-NodeMajorVersion '18.20.4') 'parses output without v prefix'

try {
  Get-NodeMajorVersion 'not-a-version'
  $failures++
} catch {
  Assert-Equal 'Unable to parse the Node.js version.' $_.Exception.Message 'rejects invalid Node output'
}

if ($failures -gt 0) { exit 1 }
Write-Host 'All installer tests passed.'
```

- [ ] **Step 2: Run the tests to verify RED**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\install.tests.ps1
```

Expected: FAIL because `install.ps1` or `Get-NodeMajorVersion` does not exist.

- [ ] **Step 3: Implement the library-safe script skeleton**

Create `install.ps1` with this shape, replacing constants only with the values verified in Task 1:

```powershell
[CmdletBinding()]
param(
  [switch]$LibraryMode,
  [switch]$PlanOnly,
  [ValidateSet('standard', 'extended')]
  [string]$ScopeSet = 'standard'
)

$ErrorActionPreference = 'Stop'
$script:PackageName = 'google-health-mcp-unofficial'
$script:PackageVersion = '0.7.6'
$script:MinimumNodeMajor = 18

function Get-NodeMajorVersion([string]$VersionText) {
  if ($VersionText -notmatch '^v?(\d+)\.') {
    throw 'Unable to parse the Node.js version.'
  }
  return [int]$Matches[1]
}

if (-not $LibraryMode) {
  Invoke-GoogleHealthMcpInstaller -PlanOnly:$PlanOnly -ScopeSet $ScopeSet
}
```

- [ ] **Step 4: Run tests to verify GREEN**

Run the test command from Step 2.

Expected: PASS with `All installer tests passed.`

- [ ] **Step 5: Add failing scope and command-plan tests**

Extend the test file to assert:

```powershell
$standard = @(Get-GoogleHealthScopeSet -Name standard)
$extended = @(Get-GoogleHealthScopeSet -Name extended)
Assert-Equal 6 $standard.Count 'standard scope count'
Assert-Equal 9 $extended.Count 'extended scope count'
Assert-Equal $true (($extended | Where-Object { $_ -notmatch '\.readonly$' }).Count -eq 0) 'extended scopes are read-only'

$plan = @(Get-UpstreamCommandPlan -ScopeSet standard)
Assert-Equal 3 $plan.Count 'setup auth doctor plan'
Assert-Equal 'setup' $plan[0].Name 'first step is setup'
Assert-Equal 'auth' $plan[1].Name 'second step is auth'
Assert-Equal 'doctor' $plan[2].Name 'third step is doctor'
```

Expected before implementation: FAIL because the functions do not exist.

- [ ] **Step 6: Implement scope and command-plan functions**

Use arrays of complete official scope URLs and return command objects shaped as:

```powershell
[pscustomobject]@{
  Name = 'setup'
  Arguments = @('-y', "$script:PackageName@$script:PackageVersion", 'setup', '--scope-preset', 'full')
  UsesScopeEnvironment = $false
}
```

The `auth` object sets `UsesScopeEnvironment = $true`; the `doctor` object appends `--live`. No object may include a Client ID, Client Secret, token, email address, or health value.

- [ ] **Step 7: Run tests and syntax checks**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\install.tests.ps1
powershell.exe -NoProfile -Command "[void][scriptblock]::Create((Get-Content -Raw -LiteralPath '.\install.ps1')); 'syntax ok'"
```

Expected: tests pass and syntax check prints `syntax ok`.

- [ ] **Step 8: Review and commit Task 2**

Inspect only `install.ps1` and `tests/install.tests.ps1`, scan them for secret-shaped values, request explicit commit authorization, then run:

```powershell
git add -- install.ps1 tests/install.tests.ps1
git commit -m "feat: add tested Google Health MCP installer core"
```

---

### Task 3: Add safe interactive orchestration and failure handling

**Files:**
- Modify: `install.ps1`
- Modify: `tests/install.tests.ps1`

**Interfaces:**
- Consumes: scope sets and command plan from Task 2.
- Produces: a guided `Invoke-GoogleHealthMcpInstaller` flow with prerequisite checks, dry-run output, injected command runner, temporary process-scoped scope configuration, and actionable exit behavior.

- [ ] **Step 1: Write failing orchestration tests**

Add a fake runner and assertions:

```powershell
$calls = [System.Collections.Generic.List[object]]::new()
$runner = {
  param([string]$Executable, [string[]]$Arguments)
  $calls.Add([pscustomobject]@{ Executable = $Executable; Arguments = $Arguments })
  return 0
}

Invoke-GoogleHealthMcpInstaller -ScopeSet standard -CommandRunner $runner -SkipPrerequisiteCheck
Assert-Equal 3 $calls.Count 'runs three upstream steps'
Assert-Equal 'npx.cmd' $calls[0].Executable 'uses Windows npx launcher'
```

Add a second runner returning `7` on `auth` and assert the installer throws `Google Health MCP auth failed with exit code 7.`. Add a dry-run case asserting the runner is never called.

- [ ] **Step 2: Run tests to verify RED**

Run the Task 2 test command.

Expected: FAIL because the orchestration parameters and behaviors are missing.

- [ ] **Step 3: Implement prerequisite checks**

`Test-InstallerPrerequisites` must:

- reject non-Windows hosts with `The automatic installer currently supports Windows only.`;
- find `node.exe` and `npx.cmd` with `Get-Command`;
- run `node --version` and parse it with `Get-NodeMajorVersion`;
- reject a version below the verified minimum with an exact actionable message;
- return the resolved `npx.cmd` path without printing environment contents.

- [ ] **Step 4: Implement external-step isolation**

`Invoke-ExternalStep` must accept an executable, argument array, step name, and injected runner. It must treat any nonzero integer result as failure and throw:

```text
Google Health MCP <step> failed with exit code <code>.
```

It must never join arguments into a shell-evaluated string.

- [ ] **Step 5: Implement temporary scope handling**

Before `auth`, save the existing process value of `GOOGLE_HEALTH_SCOPES`, set it to the selected space-separated scope list, and restore the original value in `finally`. Do not write a user- or machine-level environment variable.

- [ ] **Step 6: Implement the guided entry point**

The normal flow prints:

```text
Google Health MCP guided installer
1. Local package setup
2. Google OAuth authorization in your browser
3. Live connection diagnostic
No credentials or health data are stored by this script.
```

It explains standard versus extended read-only scopes, asks for confirmation unless `-PlanOnly` is supplied, and then executes the three planned steps. The script must not request Client ID or Client Secret itself; those remain inside the upstream setup prompt.

- [ ] **Step 7: Run all tests and dry-run verification**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\install.tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -PlanOnly -ScopeSet standard
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -PlanOnly -ScopeSet extended
```

Expected: tests pass; both dry runs show setup/auth/doctor without opening a browser or changing local configuration.

- [ ] **Step 8: Review and commit Task 3**

Inspect the exact diff, request explicit commit authorization, then run:

```powershell
git add -- install.ps1 tests/install.tests.ps1
git commit -m "feat: orchestrate setup authorization and diagnosis"
```

---

### Task 4: Write the complete Italian guide

**Files:**
- Create: `README.it.md`

**Interfaces:**
- Consumes: verified upstream constants and installer behavior from Tasks 1-3.
- Produces: the canonical end-user procedure later adapted into English.

- [ ] **Step 1: Create the Italian document skeleton**

Use these exact top-level sections:

```markdown
# Collegare Fitbit a ChatGPT e Claude con Google Health MCP

[Read in English](README.md)

## Risultato finale
## Come funziona
## Requisiti
## 1. Configura Google Cloud
## 2. Configura consenso e scope OAuth
## 3. Crea il client OAuth
## 4. Esegui l'installer su Windows
## macOS e Linux: procedura manuale
## Collega il client AI
### ChatGPT Desktop
### Claude Desktop
### Codex
### Claude Code
## Verifica in sola lettura
## Problemi comuni
## Privacy, revoca e limiti
## Crediti e licenza
```

- [ ] **Step 2: Write the Google Cloud and OAuth procedure**

Document the exact current console labels, test-user behavior, callback URI, standard read-only scopes, and optional sensitive read-only scopes. Explicitly forbid `.writeonly` scopes and use placeholders instead of account details.

- [ ] **Step 3: Document installer and manual commands**

Include:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

and the verified macOS/Linux `npx` equivalents. Explain that credentials are entered only into the local upstream wizard and must never be pasted into issues, logs, screenshots, or chat.

- [ ] **Step 4: Document all four clients from primary sources**

For each client, provide only its supported current UI path or CLI command. On native Windows, preserve any required `cmd /c npx` wrapper. Do not invent a shared configuration file.

- [ ] **Step 5: Add harmless verification and troubleshooting**

Use a read-only prompt such as:

```text
Controlla lo stato della connessione Google Health e riassumi soltanto quali categorie di dati sono disponibili, senza mostrare valori sanitari e senza effettuare modifiche.
```

Cover missing Node, OAuth callback mismatch, test user missing, stale consent after scope changes, `npx` connection closed on Windows, empty ECG/IRN results, and client restart requirements.

- [ ] **Step 6: Review Italian accuracy**

Check every command against Tasks 1-3, verify all links, and scan for personal email addresses, IDs, tokens, health values, local absolute paths, and screenshots.

- [ ] **Step 7: Commit Task 4**

After explicit commit authorization:

```powershell
git add -- README.it.md
git commit -m "docs: add Italian Google Health MCP guide"
```

---

### Task 5: Adapt and verify the English guide

**Files:**
- Create: `README.md`
- Test: `tests/readme-parity.ps1`

**Interfaces:**
- Consumes: canonical procedures in `README.it.md`.
- Produces: the GitHub landing page and a repeatable parity check.

- [ ] **Step 1: Write a failing parity test**

Create `tests/readme-parity.ps1` that extracts fenced command lines containing `install.ps1`, `google-health-mcp-unofficial`, `codex mcp`, and `claude mcp` from both READMEs, sorts them, and fails when the sets differ.

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\readme-parity.ps1
```

Expected: FAIL because `README.md` does not exist.

- [ ] **Step 2: Write the complete English adaptation**

Mirror the Italian section order, link back with `[Leggi in italiano](README.it.md)`, preserve every command exactly, and adapt prose for international technical readers rather than translating word for word.

- [ ] **Step 3: Run parity and link checks**

Run the parity test. Extract Markdown URLs from both files and verify that every HTTP link resolves to an official or explicitly attributed upstream source.

Expected: parity test passes and no broken or unexplained links remain.

- [ ] **Step 4: Commit Task 5**

After explicit commit authorization:

```powershell
git add -- README.md tests/readme-parity.ps1
git commit -m "docs: add English guide and parity check"
```

---

### Task 6: Add repository safety controls and complete validation

**Files:**
- Create: `.gitignore`
- Create: `LICENSE`
- Modify: `README.md`
- Modify: `README.it.md`

**Interfaces:**
- Consumes: all implementation and documentation from Tasks 1-5.
- Produces: a private, validated, publication-ready repository with no remote visibility change.

- [ ] **Step 1: Write `.gitignore`**

Include exact patterns for local secrets and generated artifacts:

```gitignore
.env
.env.*
!.env.example
*.log
*.token
*credentials*.json
*client_secret*.json
node_modules/
tmp/
TestResults/
```

Do not ignore READMEs, the installer, tests, specification, or plan.

- [ ] **Step 2: Add the MIT license and attribution**

Use the standard MIT text with Piermarco Giustini and 2026 for this repository's original work. In both READMEs, identify the upstream MCP package and link to its repository and license without implying authorship or endorsement.

- [ ] **Step 3: Run complete local verification**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\install.tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\readme-parity.ps1
powershell.exe -NoProfile -Command "[void][scriptblock]::Create((Get-Content -Raw -LiteralPath '.\install.ps1')); 'syntax ok'"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -PlanOnly -ScopeSet standard
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -PlanOnly -ScopeSet extended
```

Expected: every command exits 0 and no OAuth browser opens during dry runs.

- [ ] **Step 4: Perform the controlled live validation**

With the user's existing local Google Health OAuth setup, run the installer flow only after explaining that upstream setup may update local MCP configuration. Confirm `doctor --live` succeeds, but do not capture or commit health-data output. Validate at least the already proven Codex connection; label other clients as documentation-validated unless each is actually tested.

- [ ] **Step 5: Scan exact tracked and staged content**

Run:

```powershell
git status --short
git diff --check
git ls-files
rg -n -i --hidden --glob '!docs/superpowers/**' --glob '!*.lock' "client[_ -]?secret|access[_ -]?token|refresh[_ -]?token|authorization: bearer|@[a-z0-9.-]+\.[a-z]{2,}|api[_ -]?key|[A-Za-z]:\\Users\\" .
```

Review every match. Generic instructional terms are acceptable; real values, personal addresses, health values, and machine-specific paths are not.

- [ ] **Step 6: Commit the safety and release files**

After explicit commit authorization:

```powershell
git add -- .gitignore LICENSE README.md README.it.md
git commit -m "chore: add repository safety and attribution"
```

- [ ] **Step 7: Prepare the private GitHub handoff**

Show the final tracked-file list, commit history, verification summary, and secret-scan disposition. Ask separately for authorization to create the private GitHub repository and push. Do not create a remote, push, or change visibility as part of this plan step.

---

## Final Definition of Done

- The installer is Windows-only, dry-runnable, tested, and does not edit client configuration.
- OAuth is completed through the upstream local flow; no credential or token passes through this repository.
- Standard and extended choices contain read-only scopes only.
- Setup, authorization, and live diagnosis use one verified pinned upstream version.
- Both READMEs contain complete equivalent procedures and four client connection sections.
- macOS and Linux are documented as manual command paths, not automatic installer claims.
- The exact tracked scope passes tests, syntax validation, link/parity review, and secret/personal-data review.
- The repository remains local/private until separate creation, push, and later public-visibility approvals.
