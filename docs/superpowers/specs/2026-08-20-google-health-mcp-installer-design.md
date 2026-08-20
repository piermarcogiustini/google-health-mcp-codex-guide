# Google Health MCP installer and guide design

Date: 2026-08-20

## Purpose

Create a small, original repository that helps a user connect personal Fitbit data, exposed through Google Health API, to an MCP-capable AI client. The repository must remain useful as both a companion to the first PIERMARCO / LOG article and a standalone setup guide.

The project does not reimplement or copy the upstream MCP server. It provides a safe Windows installer around the existing Google Health MCP package, plus concise bilingual instructions for connecting the configured server to ChatGPT Desktop, Claude Desktop, Codex, and Claude Code.

## Product scope

Version 1 contains only:

- `README.md`, with the complete English guide;
- `README.it.md`, with the complete Italian guide;
- `install.ps1`, a guided Windows installer;
- `.gitignore`;
- an MIT license for the original installer and documentation, with separate attribution to the upstream MCP project and its license.

The repository is created privately. It becomes public only after implementation, live validation, a secret scan, review of both languages, and separate user approval.

## User journey

The README explains the full path before asking the user to run anything:

1. Understand the data flow: Fitbit to Google Health API to the local MCP server to the selected AI client.
2. Create or select a Google Cloud project.
3. Enable Google Health API.
4. Configure the OAuth consent screen and add the user's own account as a test user when required.
5. Select read-only Google Health scopes and avoid write scopes.
6. Create the OAuth web client with the documented localhost callback.
7. Run `install.ps1` on Windows.
8. Enter Client ID and Client Secret only inside the upstream local setup flow.
9. Complete consent in the browser.
10. Run the upstream live diagnostic.
11. Follow one short client-specific section to add the MCP server to ChatGPT Desktop, Claude Desktop, Codex, or Claude Code.
12. Restart the selected client and perform a harmless read-only query.

macOS and Linux users receive the equivalent upstream commands in the README, but version 1 does not claim to provide or validate an automatic installer for those systems.

## Installer behavior

`install.ps1` is an orchestrator, not a replacement MCP server. It:

- runs only on Windows in version 1;
- verifies that Node.js and `npx` are available and meet the upstream minimum version;
- explains each action before execution;
- invokes a pinned, verified release of the upstream Google Health MCP package;
- starts the upstream interactive setup without intercepting credentials;
- starts the upstream OAuth authorization flow;
- runs the upstream live diagnostic and reports success or the next actionable failure;
- returns nonzero when a required step fails;
- never edits ChatGPT, Claude, Codex, or Claude Code configuration files;
- never logs or prints secrets, authorization codes, access tokens, refresh tokens, or health records.

The implementation will revalidate the current upstream package and official setup documentation before selecting the pinned version. The previously proven flow used `google-health-mcp-unofficial@0.7.6`; that is a compatibility baseline, not an instruction to upgrade blindly or use an unverified latest version.

## Client support

The same installed local MCP server is reused. The READMEs provide the smallest supported connection procedure for:

- ChatGPT Desktop;
- Claude Desktop;
- Codex;
- Claude Code.

Client configuration remains manual in version 1. This keeps the installer safe, avoids corrupting user configuration, and removes the need to maintain operating-system-specific configuration writers.

## Security and privacy

The public repository must contain no real identifiers, email addresses, OAuth credentials, tokens, health records, screenshots with personal data, or local configuration exports.

The guide must:

- use placeholders for every user-specific value;
- recommend only scopes ending in `.readonly`;
- explain a minimal-scope default and label extra sensitive scopes clearly;
- recommend the upstream `structured` privacy mode;
- state that health data sent to an AI client is sensitive and should be minimized;
- distinguish wellness summaries from medical diagnosis or advice;
- instruct users to revoke Google access and remove local tokens if they stop using the integration.

The installer may inherit secrets through the upstream interactive process, but it must not accept them as command-line arguments or save them inside the repository.

## Documentation design

The English and Italian READMEs are complete equivalents. The English README is the GitHub default; each README links to the other at the top.

Both use the same order:

1. Outcome and architecture.
2. Requirements.
3. Google Cloud and OAuth setup.
4. Installer execution.
5. Connection instructions for the four clients.
6. Verification prompt.
7. Troubleshooting.
8. Privacy, revocation, attribution, and limitations.

Commands remain identical across translations. English text is adapted for technical readers rather than translated mechanically.

## Validation

Before publication:

- syntax-check the PowerShell script;
- test prerequisite, cancellation, upstream-command failure, and successful orchestration paths without exposing real credentials;
- run the installer end to end on Windows using the existing personal OAuth setup only where a live step is necessary;
- confirm the diagnostic succeeds without recording its health-data output;
- validate each documented client configuration against current official client documentation;
- scan the exact tracked and staged files for secrets and personal data;
- verify all links and compare the Italian and English procedures for functional parity.

Success means a clean Windows user can follow the guide, complete OAuth locally, connect at least one supported client, and execute a read-only health summary without placing credentials or health data in the repository.

## Non-goals for version 1

- Reimplementing or forking the upstream MCP server.
- Automatically editing client configuration files.
- A graphical installer.
- Automatic installers for macOS or Linux.
- Hosting a remote MCP server or storing users' health data.
- Medical recommendations or diagnostic interpretation.
- Publishing the GitHub repository or the PIERMARCO / LOG article without explicit approval.

## Article relationship

The repository is the reproducible setup companion. The first PIERMARCO / LOG article tells the personal engineering story: why Google Health API was chosen, how the authorization flow works, what failed, which privacy trade-offs mattered, and what became reusable.

The article will be drafted in Italian, adapted into English, previewed in both languages, and published only after explicit approval. It links to the repository once the repository is public; the README links back to the article after the article is live.
