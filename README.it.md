# Collegare Fitbit a ChatGPT e Claude con Google Health MCP

[Read in English](README.md)

Guida indipendente e installatore Windows per il progetto open source
[`google-health-mcp`](https://github.com/davidmosiah/google-health-mcp). La repo
non contiene dati sanitari, credenziali o token.

## Risultato finale

Un server MCP locale, in sola lettura, che permette a un client compatibile di
interrogare i dati Fitbit disponibili tramite le Google Health API. La procedura
usa `google-health-mcp-unofficial@0.7.6`, Node.js 20+ e la modalità privacy
`structured`.

> ChatGPT non si collega direttamente a un processo MCP locale via `stdio`. Le
> custom app MCP richiedono un endpoint raggiungibile; il Secure MCP Tunnel di
> OpenAI è l'opzione per gli ambienti privati abilitati. Il supporto MCP completo
> è attualmente in beta e dipende dal piano e dai permessi del workspace. Vedi la
> [documentazione OpenAI aggiornata](https://help.openai.com/en/articles/12584461-developer-mode-apps-and-full-mcp-connectors-in-chatgpt-beta).
> Codex, Claude Desktop e Claude Code possono avviare direttamente questo server
> locale.

## Come funziona

1. Crei un progetto Google Cloud e un client OAuth.
2. L'installer salva la configurazione privata sotto `~/.google-health-mcp`.
3. Autorizzi Google Health nel browser.
4. Colleghi manualmente il client AI che vuoi usare.

L'installer non modifica la configurazione di alcun client AI.

## Requisiti

- Windows 10/11 per l'installer automatico;
- [Node.js](https://nodejs.org/) 20 o successivo;
- un account Google con dati Fitbit/Google Health disponibili;
- accesso a [Google Cloud Console](https://console.cloud.google.com/).

## 1. Configura Google Cloud

1. Crea o seleziona un progetto in Google Cloud Console.
2. Apri **APIs & Services > Library** e abilita la Fitbit API/Google Health API
   indicata dalla [guida ufficiale](https://developers.google.com/health/setup).
3. Apri **Google Auth Platform** e configura il progetto OAuth.

Google può cambiare leggermente le etichette della console: usa sempre la guida
ufficiale come riferimento principale.

## 2. Configura consenso e scope OAuth

Imposta il pubblico su **External** e, finché l'app è in test, aggiungi il tuo
account in **Test users**. Richiedi soltanto gli scope necessari.

Set standard read-only:

```text
https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly
https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly
https://www.googleapis.com/auth/googlehealth.nutrition.readonly
https://www.googleapis.com/auth/googlehealth.profile.readonly
https://www.googleapis.com/auth/googlehealth.settings.readonly
https://www.googleapis.com/auth/googlehealth.sleep.readonly
```

Il set `extended` aggiunge ECG, notifiche di ritmo irregolare e posizione GPS:

```text
https://www.googleapis.com/auth/googlehealth.ecg.readonly
https://www.googleapis.com/auth/googlehealth.irn.readonly
https://www.googleapis.com/auth/googlehealth.location.readonly
```

Non aggiungere scope `.write` o `.writeonly`. Elenco aggiornato:
[Google Health OAuth scopes](https://developers.google.com/health/scopes).

Nota: con un'app OAuth in stato **Testing**, il refresh token può scadere dopo
sette giorni; in quel caso ripeti l'autorizzazione.

## 3. Crea il client OAuth

1. In **Google Auth Platform > Clients**, crea un client OAuth di tipo
   **Web application**.
2. Inserisci questo URI esatto tra gli URI di reindirizzamento autorizzati:

```text
http://127.0.0.1:3000/callback
```

3. Conserva Client ID e Client Secret localmente. Non inserirli nella repo, in
   issue, screenshot, log o chat.

## 4. Esegui l'installer su Windows

Apri PowerShell nella cartella della repo e prova prima il piano:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -PlanOnly
```

Poi avvia la procedura standard:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

Per includere anche ECG, IRN e posizione:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -ScopeSet extended
```

Il wizard upstream chiede Client ID e Client Secret localmente, apre il consenso
Google e infine esegue una diagnosi live. Lo script non legge né stampa i
segreti.

## macOS e Linux: procedura manuale

Richiede Node.js 20+. Esegui, nell'ordine:

```bash
npx -y google-health-mcp-unofficial@0.7.6 setup --client generic --scope-preset basic --privacy-mode structured --no-auth
npx -y google-health-mcp-unofficial@0.7.6 auth
npx -y google-health-mcp-unofficial@0.7.6 doctor --live
```

Il comando manuale usa il preset `basic`. Per replicare esattamente gli scope
personalizzati dell'installer Windows, imposta `GOOGLE_HEALTH_SCOPES` soltanto
nel processo di `auth`, usando gli URL elencati sopra separati da spazi.

## Collega il client AI

Questi passaggi modificano la configurazione del client e sono intenzionalmente
manuali.

### ChatGPT Desktop

Secondo la [documentazione OpenAI](https://help.openai.com/en/articles/12584461-developer-mode-and-full-mcp-apps-in-chatgpt-beta),
ChatGPT non raggiunge direttamente un server MCP locale. Le opzioni sicure sono:

- usare il server locale in Codex;
- pubblicare un endpoint **Streamable HTTP** protetto;
- usare il **Secure MCP Tunnel** di OpenAI per una macchina privata.

Questa prima versione non automatizza tunnel o hosting: esporre dati sanitari
richiede autenticazione, controllo accessi e una revisione di sicurezza dedicata.

### Claude Desktop

Apri **Settings > Developer > Edit Config** e aggiungi il server alla mappa
`mcpServers`, preservando le altre voci:

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

Salva e riavvia Claude Desktop. Controlla lo stato da **Settings > Developer** o
dal pulsante **+ > Connectors** nella chat.

### Codex

In PowerShell:

```powershell
codex mcp add google_health -- cmd /c npx -y google-health-mcp-unofficial@0.7.6
codex mcp list
```

Puoi anche aggiungere lo stesso server dalla sezione MCP delle impostazioni di
Codex. Riferimento: [OpenAI MCP documentation](https://learn.chatgpt.com/docs/extend/mcp?surface=cli).

### Claude Code

In PowerShell, aggiungilo a livello utente:

```powershell
claude mcp add --transport stdio --scope user google_health -- cmd /c npx -y google-health-mcp-unofficial@0.7.6
claude mcp list
```

Dentro Claude Code usa `/mcp` per verificarne lo stato. Riferimento:
[Claude Code MCP](https://code.claude.com/docs/en/mcp).

## Verifica in sola lettura

Prima prova `doctor --live`, poi usa questo prompt:

```text
Controlla lo stato della connessione Google Health e riassumi soltanto quali categorie di dati sono disponibili, senza mostrare valori sanitari e senza effettuare modifiche.
```

## Problemi comuni

- **Node o npx non trovato:** installa Node.js 20+ e riapri PowerShell.
- **Redirect URI mismatch:** verifica l'URI esatto, incluso `127.0.0.1` e la porta
  `3000`.
- **Access blocked/test user:** aggiungi l'account tra i Test users.
- **Scope cambiati:** revoca il consenso precedente e ripeti `auth`.
- **Connection closed su Windows:** usa il wrapper `cmd /c npx` nei client.
- **ECG o IRN vuoti:** i dati possono non essere disponibili per account,
  dispositivo, paese o periodo selezionato.
- **Tool non visibili:** riavvia il client dopo aver aggiornato la configurazione.

## Privacy, revoca e limiti

- I segreti e i token restano in `~/.google-health-mcp`, non nella repo.
- Usa `structured`, scope read-only e il principio del minimo privilegio.
- Revoca l'accesso dalla pagina sicurezza del tuo account Google quando non serve.
- Non condividere output contenenti dati sanitari.
- Il progetto upstream è non ufficiale e può cambiare; questa non è una
  integrazione medica né uno strumento diagnostico.

## Crediti e licenza

Installer e guida: licenza MIT. Server MCP upstream:
[`davidmosiah/google-health-mcp`](https://github.com/davidmosiah/google-health-mcp),
anch'esso MIT. Google, Fitbit, OpenAI e Anthropic non sponsorizzano questa repo.
