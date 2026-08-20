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

$calls = [System.Collections.Generic.List[object]]::new()
$runner = {
    param([string]$Executable, [string[]]$Arguments)
    $calls.Add([pscustomobject]@{ Executable = $Executable; Arguments = $Arguments })
    return 0
}
Invoke-GoogleHealthMcpInstaller -ScopeSet standard -CommandRunner $runner -SkipPrerequisiteCheck
Assert-Equal 3 $calls.Count 'runs three upstream steps'
Assert-Equal 'npx.cmd' $calls[0].Executable 'uses Windows npx launcher'
Assert-Equal $null $env:GOOGLE_HEALTH_SCOPES 'restores absent scope environment'

$env:GOOGLE_HEALTH_SCOPES = 'original-value'
$null = Invoke-GoogleHealthMcpInstaller -ScopeSet extended -CommandRunner $runner -SkipPrerequisiteCheck
Assert-Equal 'original-value' $env:GOOGLE_HEALTH_SCOPES 'restores existing scope environment'
Remove-Item Env:GOOGLE_HEALTH_SCOPES

$failed = $false
$failureRunner = {
    param([string]$Executable, [string[]]$Arguments)
    if ($Arguments -contains 'auth') { return 7 }
    return 0
}
try {
    Invoke-GoogleHealthMcpInstaller -CommandRunner $failureRunner -SkipPrerequisiteCheck
} catch {
    $failed = $true
    Assert-Equal 'Google Health MCP auth failed with exit code 7.' $_.Exception.Message 'propagates step failure'
}
Assert-Equal $true $failed 'auth failure throws'

$dryRunCalls = 0
$dryRunner = { param($Executable, $Arguments) $script:dryRunCalls++; return 0 }
Invoke-GoogleHealthMcpInstaller -PlanOnly -CommandRunner $dryRunner -SkipPrerequisiteCheck
Assert-Equal 0 $dryRunCalls 'plan only does not execute commands'

if ($failures -gt 0) { exit 1 }
Write-Host 'All installer tests passed.'
