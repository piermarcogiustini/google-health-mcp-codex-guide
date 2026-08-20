# Connect Fitbit to ChatGPT and Claude with Google Health MCP

[Leggi in italiano](README.it.md)

An independent guide and Windows installer for the open-source
[`google-health-mcp`](https://github.com/davidmosiah/google-health-mcp) project.
This repository contains no health data, credentials, or tokens.

## End result

A read-only local MCP server that lets a compatible client query Fitbit data
available through Google Health APIs. The workflow uses
`google-health-mcp-unofficial@0.7.6`, Node.js 20+, and `structured` privacy mode.

> ChatGPT web/desktop cannot connect directly to a local MCP server. ChatGPT
> requires a remote MCP endpoint or OpenAI Secure MCP Tunnel. Codex, Claude
> Desktop, and Claude Code can start this local server directly.

## How it works

1. Create a Google Cloud project and OAuth client.
2. The installer saves private configuration under `~/.google-health-mcp`.
3. Authorize Google Health in your browser.
4. Manually connect your chosen AI client.

The installer never edits an AI client's configuration.

## Requirements

- Windows 10/11 for the automatic installer;
- [Node.js](https://nodejs.org/) 20 or newer;
- a Google account with available Fitbit/Google Health data;
- access to [Google Cloud Console](https://console.cloud.google.com/).

## 1. Configure Google Cloud

1. Create or select a project in Google Cloud Console.
2. Open **APIs & Services > Library** and enable the Fitbit/Google Health API
   named in the [official setup guide](https://developers.google.com/health/setup).
3. Open **Google Auth Platform** and configure the OAuth project.

Console labels may change slightly; treat the official guide as authoritative.

## 2. Configure OAuth consent and scopes

Set the audience to **External** and, while the app is in testing, add your
account under **Test users**. Request only the scopes you need.

Standard read-only set:

```text
https://www.googleapis.com/auth/fitbit.activity_and_fitness.readonly
https://www.googleapis.com/auth/fitbit.health_metrics_and_measurements.readonly
https://www.googleapis.com/auth/fitbit.nutrition.readonly
https://www.googleapis.com/auth/fitbit.profile.readonly
https://www.googleapis.com/auth/fitbit.settings.readonly
https://www.googleapis.com/auth/fitbit.sleep.readonly
```

The `extended` set adds ECG, irregular-rhythm notifications, and GPS location:

```text
https://www.googleapis.com/auth/fitbit.ecg.readonly
https://www.googleapis.com/auth/fitbit.irn.readonly
https://www.googleapis.com/auth/fitbit.location.readonly
```

Do not add `.write` or `.writeonly` scopes. See the current
[Google Health OAuth scopes](https://developers.google.com/health/scopes).

Note: while an OAuth app remains in **Testing**, its refresh token may expire
after seven days. Run authorization again when needed.

## 3. Create the OAuth client

1. In **Google Auth Platform > Clients**, create a **Web application** OAuth
   client.
2. Add this exact authorized redirect URI:

```text
http://127.0.0.1:3000/callback
```

3. Keep the Client ID and Client Secret local. Never put them in this repository,
   issues, screenshots, logs, or chats.

## 4. Run the installer on Windows

Open PowerShell in the repository folder and inspect the plan first:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -PlanOnly
```

Then run the standard workflow:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

To include ECG, IRN, and location:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -ScopeSet extended
```

The upstream wizard requests Client ID and Client Secret locally, opens Google
consent, and runs a live diagnostic. This script never reads or prints secrets.

## macOS and Linux: manual workflow

Node.js 20+ is required. Run these commands in order:

```bash
npx -y google-health-mcp-unofficial@0.7.6 setup --client generic --scope-preset basic --privacy-mode structured --no-auth
npx -y google-health-mcp-unofficial@0.7.6 auth
npx -y google-health-mcp-unofficial@0.7.6 doctor --live
```

The manual command uses the `basic` preset. To reproduce the Windows installer's
custom scopes exactly, set `GOOGLE_HEALTH_SCOPES` only for the `auth` process,
using the space-separated URLs above.

## Connect the AI client

These steps intentionally leave client configuration changes to you.

### ChatGPT Desktop

According to [OpenAI documentation](https://help.openai.com/en/articles/12584461-developer-mode-and-full-mcp-apps-in-chatgpt-beta),
ChatGPT cannot directly reach a local MCP server. Safe options are:

- use the local server in Codex;
- deploy an authenticated **Streamable HTTP** endpoint;
- use **OpenAI Secure MCP Tunnel** for a private machine.

This first version does not automate tunneling or hosting. Exposing health data
requires authentication, access control, and a dedicated security review.

### Claude Desktop

Open **Settings > Developer > Edit Config** and add the server under
`mcpServers`, preserving existing entries:

```json
{
  "mcpServers": {
    "google_health": {
      "command": "cmd",
      "args": ["/c", "npx", "-y", "google-health-mcp-unofficial@0.7.6"]
    }
  }
}
```

Save and restart Claude Desktop. Check **Settings > Developer** or
**+ > Connectors** in a chat.

### Codex

In PowerShell:

```powershell
codex mcp add google_health -- cmd /c npx -y google-health-mcp-unofficial@0.7.6
codex mcp list
```

The same server can be added from Codex MCP settings. Reference:
[OpenAI MCP documentation](https://learn.chatgpt.com/docs/extend/mcp?surface=cli).

### Claude Code

In PowerShell, add it at user scope:

```powershell
claude mcp add --transport stdio --scope user google_health -- cmd /c npx -y google-health-mcp-unofficial@0.7.6
claude mcp list
```

Inside Claude Code, use `/mcp` to check its status. Reference:
[Claude Code MCP](https://code.claude.com/docs/en/mcp).

## Read-only verification

Run `doctor --live`, then try this prompt:

```text
Check the Google Health connection and summarize only which data categories are available. Do not show health values and do not make changes.
```

## Common problems

- **Node or npx not found:** install Node.js 20+ and reopen PowerShell.
- **Redirect URI mismatch:** verify the exact URI, including `127.0.0.1` and port
  `3000`.
- **Access blocked/test user:** add the account under Test users.
- **Scopes changed:** revoke the old consent and run `auth` again.
- **Connection closed on Windows:** use the `cmd /c npx` wrapper in clients.
- **Empty ECG or IRN:** data may be unavailable for the account, device, country,
  or selected period.
- **Tools missing:** restart the client after changing its configuration.

## Privacy, revocation, and limitations

- Secrets and tokens stay in `~/.google-health-mcp`, outside this repository.
- Use `structured`, read-only scopes, and least privilege.
- Revoke access from your Google Account security page when no longer needed.
- Never share output containing health data.
- The upstream project is unofficial and may change. This is neither a medical
  integration nor a diagnostic tool.

## Credits and license

Installer and guide: MIT License. Upstream MCP server:
[`davidmosiah/google-health-mcp`](https://github.com/davidmosiah/google-health-mcp),
also MIT. Google, Fitbit, OpenAI, and Anthropic do not sponsor this repository.
