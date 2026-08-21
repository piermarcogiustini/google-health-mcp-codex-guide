$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

function Get-SharedCommands([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "Missing README: $Path" }
    $insideFence = $false
    $commands = foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^```') { $insideFence = -not $insideFence; continue }
        if ($insideFence -and $line -match '(install\.ps1|google-health-mcp-unofficial|codex mcp|claude mcp)') {
            $line.Trim()
        }
    }
    $commands | Sort-Object -Unique
}

$italian = @(Get-SharedCommands (Join-Path $root 'README.it.md'))
$english = @(Get-SharedCommands (Join-Path $root 'README.md'))
$difference = Compare-Object $italian $english
if ($difference) {
    $difference | Format-Table -AutoSize
    throw 'English and Italian command sets differ.'
}

foreach ($readme in @('README.it.md', 'README.md')) {
    $content = Get-Content -LiteralPath (Join-Path $root $readme) -Raw
    if ($content -match 'https://www\.googleapis\.com/auth/fitbit\.') {
        throw "$readme contains the invalid Fitbit OAuth namespace."
    }
    if ($content -notmatch 'https://www\.googleapis\.com/auth/googlehealth\.') {
        throw "$readme does not document the Google Health OAuth namespace."
    }
}
Write-Host 'README command parity passed.'
