#Requires -Version 7.0
#Requires -Modules Microsoft.Graph
<#
.SYNOPSIS
    Reports per-user MFA registration status from Graph authentication methods.

.DESCRIPTION
    Read-only report. Lists each user's registered authentication methods and
    flags users with no MFA-capable method (authenticator app, phone, FIDO2
    security key, Windows Hello, software OATH token, or Temporary Access Pass).

    This is REGISTRATION status, not enforcement. A user can be registered for
    MFA and still never be challenged if no Conditional Access policy requires
    it. Email and password alone do not count as MFA - email is only used for
    password reset.

    Required Graph scopes: User.Read.All, UserAuthenticationMethod.Read.All.

.PARAMETER OutputPath
    Path for the CSV report. Defaults to mfa-status-report-<date>.csv in the current folder.

.EXAMPLE
    .\09-mfa-status-report.ps1
    Exports every user with their MFA status to a CSV.

.NOTES
    Users flagged "NO MFA" are the ones to chase first. Start with admins and
    anyone with access to finance or email.
    This script changes nothing; it only reports.
#>
[CmdletBinding()]
param(
    [string]$OutputPath = ".\mfa-status-report-$(Get-Date -Format 'yyyyMMdd').csv"
)

if (-not (Get-MgContext)) {
    throw 'Not connected to Microsoft Graph. Run Connect-MgGraph first (see README.md).'
}

$users = Get-MgUser -All -Property Id, DisplayName, UserPrincipalName, AccountEnabled

$report = foreach ($user in $users) {
    $methods = Get-MgUserAuthenticationMethod -UserId $user.Id -All
    $names = @()
    $hasMfa = $false

    foreach ($method in $methods) {
        $type = $method.AdditionalProperties['@odata.type'] -replace '^#microsoft.graph.', ''
        switch ($type) {
            'microsoftAuthenticatorAuthenticationMethod'          { $names += 'Authenticator app'; $hasMfa = $true }
            'phoneAuthenticationMethod'                           { $names += 'Phone (SMS/voice)'; $hasMfa = $true }
            'fido2AuthenticationMethod'                           { $names += 'FIDO2 security key'; $hasMfa = $true }
            'windowsHelloForBusinessAuthenticationMethod'         { $names += 'Windows Hello'; $hasMfa = $true }
            'softwareOathAuthenticationMethod'                    { $names += 'Software OATH token'; $hasMfa = $true }
            'temporaryAccessPassAuthenticationMethod'             { $names += 'Temporary Access Pass'; $hasMfa = $true }
            'emailAuthenticationMethod'                           { $names += 'Email (password reset only)' }
            'passwordAuthenticationMethod'                        { $names += 'Password' }
            default                                               { $names += $type }
        }
    }

    [pscustomobject]@{
        DisplayName       = $user.DisplayName
        UserPrincipalName = $user.UserPrincipalName
        AccountEnabled    = $user.AccountEnabled
        MfaStatus         = if ($hasMfa) { 'MFA registered' } else { 'NO MFA' }
        MethodCount       = $methods.Count
        Methods           = ($names -join '; ')
    }
}

$report | Sort-Object MfaStatus, DisplayName | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8

$noMfa = $report | Where-Object { $_.MfaStatus -eq 'NO MFA' }
Write-Host "Users checked: $($report.Count). Users with no MFA method: $($noMfa.Count). Report: $OutputPath" -ForegroundColor Cyan
if ($noMfa) {
    Write-Host 'Users with no MFA:' -ForegroundColor Yellow
    $noMfa | Select-Object DisplayName, UserPrincipalName | Format-Table -AutoSize
}
