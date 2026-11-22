# MFA status report — one read-only PowerShell script

Check every user's MFA registration status in Microsoft 365 and export it to CSV. One script, one report: who has an MFA method registered (authenticator app, phone, FIDO2 key, Windows Hello, OATH token, Temporary Access Pass) and who has **NO MFA** — the people to chase first.

**It changes nothing.** The only Microsoft 365 commands are `Get-MgUser` and `Get-MgUserAuthenticationMethod` — both reads. No `Set-`, `New-`, `Update-`, or `Remove-` commands anywhere. No secrets, no remote code. The only thing it creates is a CSV on your own computer.

## What it reports

Registration status, not enforcement. A user can be registered for MFA and still never be challenged if no Conditional Access policy requires it — this script tells you who is registered, which is the first thing to fix.

## Requirements

- PowerShell 7 (Windows 10/11 or Windows Server). Windows PowerShell 5.1 will not run it — the `#Requires -Version 7.0` line stops it with a clear error.
- A Microsoft 365 admin account (User Administrator or Global Administrator).
- No Entra ID P1/P2 needed.

## Quick start

```powershell
# 1. Install the Graph module (once)
Install-Module Microsoft.Graph -Scope CurrentUser -Force

# 2. Connect with two read scopes
Connect-MgGraph -Scopes "User.Read.All", "UserAuthenticationMethod.Read.All"

# 3. Run it
.\09-mfa-status-report.ps1
```

Output: `mfa-status-report-<date>.csv` in the current folder. Use `-OutputPath` to choose another file.

## Reading the CSV

Open it in Excel, or query it from PowerShell:

```powershell
$report = Import-Csv .\mfa-status-report-20261122.csv
$report | Where-Object { $_.MfaStatus -eq 'NO MFA' } | Select-Object DisplayName, UserPrincipalName
```

Start with admins and anyone with access to finance or email.

## More scripts

The full PowerShell Admin Toolkit ($79) has ten scripts that build on the same pattern — user export, licence reports, inactive users, and more:
https://yossimeisner.gumroad.com

## Safety

- Read-only: `Get-MgUser`, `Get-MgUserAuthenticationMethod`, `Get-MgContext` only.
- No passwords, keys, or tokens in any file. You sign in interactively with your own admin account.
- Test-first: try it in a trial or dev tenant first, and compare the row count with Users > Active users in the admin center.
