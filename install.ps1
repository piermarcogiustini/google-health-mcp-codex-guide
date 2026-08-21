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
$script:MinimumNodeMajor = 20

function Get-NodeMajorVersion([string]$VersionText) {
    if ($VersionText -notmatch '^v?(\d+)\.') {
        throw 'Unable to parse the Node.js version.'
    }
    return [int]$Matches[1]
}

function Get-GoogleHealthScopeSet {
    param([ValidateSet('standard', 'extended')][string]$Name = 'standard')

    $base = @(
        'https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly'
        'https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly'
        'https://www.googleapis.com/auth/googlehealth.nutrition.readonly'
        'https://www.googleapis.com/auth/googlehealth.profile.readonly'
        'https://www.googleapis.com/auth/googlehealth.settings.readonly'
        'https://www.googleapis.com/auth/googlehealth.sleep.readonly'
    )
    if ($Name -eq 'extended') {
        return $base + @(
            'https://www.googleapis.com/auth/googlehealth.ecg.readonly'
            'https://www.googleapis.com/auth/googlehealth.irn.readonly'
            'https://www.googleapis.com/auth/googlehealth.location.readonly'
        )
    }
    return $base
}

function Get-UpstreamCommandPlan {
    param([ValidateSet('standard', 'extended')][string]$ScopeSet = 'standard')

    $package = "$script:PackageName@$script:PackageVersion"
    @(
        [pscustomobject]@{
            Name = 'setup'
            Arguments = @('-y', $package, 'setup', '--client', 'generic', '--scope-preset', 'basic', '--privacy-mode', 'structured', '--no-auth')
            UsesScopeEnvironment = $false
        }
        [pscustomobject]@{
            Name = 'auth'
            Arguments = @('-y', $package, 'auth')
            UsesScopeEnvironment = $true
        }
        [pscustomobject]@{
            Name = 'doctor'
            Arguments = @('-y', $package, 'doctor', '--live')
            UsesScopeEnvironment = $false
        }
    )
}

function Test-InstallerPrerequisites {
    if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
        throw 'The automatic installer currently supports Windows only.'
    }
    $node = Get-Command node.exe -ErrorAction SilentlyContinue
    $npx = Get-Command npx.cmd -ErrorAction SilentlyContinue
    if (-not $node -or -not $npx) {
        throw 'Node.js 20 or newer is required. Install it from https://nodejs.org and reopen PowerShell.'
    }
    $major = Get-NodeMajorVersion (& $node.Source --version)
    if ($major -lt $script:MinimumNodeMajor) {
        throw "Node.js $script:MinimumNodeMajor or newer is required; detected major version $major."
    }
    return $npx.Source
}

function Invoke-ExternalStep {
    param(
        [Parameter(Mandatory)][string]$Executable,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$StepName,
        [scriptblock]$CommandRunner
    )

    if ($CommandRunner) {
        $code = & $CommandRunner $Executable $Arguments
    } else {
        & $Executable @Arguments
        $code = $LASTEXITCODE
    }
    if ($null -eq $code) { $code = 0 }
    if ([int]$code -ne 0) {
        throw "Google Health MCP $StepName failed with exit code $code."
    }
}

function Invoke-GoogleHealthMcpInstaller {
    [CmdletBinding()]
    param(
        [ValidateSet('standard', 'extended')][string]$ScopeSet = 'standard',
        [switch]$PlanOnly,
        [scriptblock]$CommandRunner,
        [switch]$SkipPrerequisiteCheck
    )

    Write-Host 'Google Health MCP guided installer'
    Write-Host '1. Local package setup'
    Write-Host '2. Google OAuth authorization in your browser'
    Write-Host '3. Live connection diagnostic'
    Write-Host 'No credentials or health data are stored by this script.'
    Write-Host "Scope set: $ScopeSet (read-only)"

    $plan = @(Get-UpstreamCommandPlan -ScopeSet $ScopeSet)
    if ($PlanOnly) {
        foreach ($step in $plan) {
            Write-Host ("PLAN {0}: npx.cmd {1}" -f $step.Name, ($step.Arguments -join ' '))
        }
        return
    }

    if (-not $CommandRunner) {
        $answer = Read-Host 'Continue? [y/N]'
        if ($answer -notmatch '^(y|yes|s|si)$') {
            Write-Host 'Cancelled. No changes were made by this script.'
            return
        }
    }

    $npxPath = if ($SkipPrerequisiteCheck) { 'npx.cmd' } else { Test-InstallerPrerequisites }
    $originalScopes = [Environment]::GetEnvironmentVariable('GOOGLE_HEALTH_SCOPES', 'Process')
    try {
        foreach ($step in $plan) {
            if ($step.UsesScopeEnvironment) {
                $selectedScopes = @(Get-GoogleHealthScopeSet -Name $ScopeSet)
                [Environment]::SetEnvironmentVariable('GOOGLE_HEALTH_SCOPES', ($selectedScopes -join ' '), 'Process')
            }
            Invoke-ExternalStep -Executable $npxPath -Arguments $step.Arguments -StepName $step.Name -CommandRunner $CommandRunner
        }
    } finally {
        [Environment]::SetEnvironmentVariable('GOOGLE_HEALTH_SCOPES', $originalScopes, 'Process')
    }
    Write-Host 'Setup, authorization, and live diagnostic completed.'
}

if (-not $LibraryMode) {
    Invoke-GoogleHealthMcpInstaller -PlanOnly:$PlanOnly -ScopeSet $ScopeSet
}
