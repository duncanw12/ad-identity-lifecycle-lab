# Identity & Access Lifecycle Lab

A Windows Server Active Directory lab demonstrating identity lifecycle automation, role-based access control, least-privilege delegation, Microsoft 365 / Entra ID administration concepts, and Tier 1 support troubleshooting.

## What this project demonstrates
- Windows Server 2025 Active Directory Domain Services and DNS
- PowerShell automation for joiner, password-reset, access-review, and leaver workflows
- AGDLP role-based access control
- Delegated helpdesk password-reset and unlock permissions without Domain Admin
- SMB share permissions and Effective Access validation
- Account lockout troubleshooting
- RDP troubleshooting using network -> port -> service -> firewall -> account isolation
- Microsoft 365 mailbox delegation concepts
- Entra ID MFA, SSO, admin roles, hybrid identity, and Azure RBAC
- Ticket documentation and escalation discipline

## Architecture

```text
Windows 11 Pro Host
   |
   | Hyper-V / LabNAT 192.168.50.0/24
   |
   +-- DC01 - 192.168.50.10
       |-- Windows Server 2025
       |-- AD DS / DNS
       |-- Domain: lab.local
       |-- OU=Lab
           |-- OU=Users
           |-- OU=Groups
           |-- OU=Disabled
```

## Access model - AGDLP

```text
Users -> Global role groups -> Domain Local resource groups -> ACLs

Ava Brooks (FrontDesk)
  -> GG_FrontDesk
     -> DL_Schedules_Read
        -> \\DC01\Schedules (Read)

Liam Carter (OfficeManager)
  -> GG_OfficeManager
     -> DL_Schedules_Read
     -> DL_Finance_Modify
        -> \\DC01\Finance (Modify)

Noah Diaz (Helpdesk)
  -> GG_Helpdesk
     -> delegated reset/unlock rights on OU=Users only
```

## Repository contents
- `IdentityLifecycle.ps1` - AD lifecycle automation and delegated access setup
- `new-hires.csv` - sample joiner input data
- `M365-Access-Runbook.md` - cloud identity and mailbox-access runbook
- `tickets.md` - five simulated support tickets
- `sample-output/` - replace placeholders with output generated from the live lab
- `screenshots/` - add evidence screenshots listed below

## Build and run

### 1. Load the script
```powershell
cd C:\Lab
. .\IdentityLifecycle.ps1
```

### 2. Build OUs, groups, AGDLP nesting, and delegation
```powershell
New-LabStructure
```

### 3. Create the four lab users
```powershell
Add-LabUser
```

### 4. Create the resource shares
```powershell
New-Item C:\Shares\Schedules, C:\Shares\Finance -ItemType Directory -Force

New-SmbShare -Name Schedules -Path C:\Shares\Schedules `
  -FullAccess 'LAB\Domain Admins' `
  -ReadAccess 'LAB\DL_Schedules_Read'

New-SmbShare -Name Finance -Path C:\Shares\Finance `
  -FullAccess 'LAB\Domain Admins' `
  -ChangeAccess 'LAB\DL_Finance_Modify'

icacls C:\Shares\Schedules /grant 'LAB\DL_Schedules_Read:(OI)(CI)RX'
icacls C:\Shares\Finance /grant 'LAB\DL_Finance_Modify:(OI)(CI)M'
```

### 5. Set the domain lockout policy
```powershell
Set-ADDefaultDomainPasswordPolicy -Identity lab.local `
  -LockoutThreshold 5 `
  -LockoutDuration 00:15:00 `
  -LockoutObservationWindow 00:15:00
```

### 6. Helpdesk least-privilege test
Give Noah Diaz a known test password and disable the change-at-logon requirement:

```powershell
Set-ADAccountPassword ndiaz -Reset -NewPassword (Read-Host 'ndiaz password' -AsSecureString)
Set-ADUser ndiaz -ChangePasswordAtLogon $false
$hd = Get-Credential LAB\ndiaz
```

Password reset should succeed:

```powershell
Set-ADAccountPassword abrooks -Reset `
  -NewPassword (Read-Host 'new Ava password' -AsSecureString) `
  -Credential $hd
```

Account disable should fail with Access Denied:

```powershell
Disable-ADAccount abrooks -Credential $hd
```

### 7. Work the lifecycle tickets
```powershell
Reset-LabPassword -Sam abrooks -Ticket INC1001
Disable-LabUser -Sam mevans -Ticket REQ2001
Get-LabAccessReport
```

### 8. RDP troubleshooting simulation
From the VM console:

```powershell
Disable-NetFirewallRule -DisplayGroup 'Remote Desktop'
```

From the host:

```powershell
Test-NetConnection 192.168.50.10 -Port 3389
Test-NetConnection 192.168.50.10
```

Back in the VM:

```powershell
Get-Service TermService
Get-NetFirewallRule -DisplayGroup 'Remote Desktop' | Select-Object DisplayName,Enabled
Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'
```

Then verify from the host:

```powershell
Test-NetConnection 192.168.50.10 -Port 3389
mstsc /v:192.168.50.10
```

## Required evidence screenshots
Before publishing, place screenshots in `screenshots/` with descriptive filenames:
1. `01-aduc-lab-ou-tree.png` - Lab OU with Users, Groups, and Disabled OUs.
2. `02-dl-schedules-members.png` - `DL_Schedules_Read` showing nested role groups.
3. `03-finance-effective-access-allowed.png` - Liam Carter allowed.
4. `04-finance-effective-access-denied.png` - Ava Brooks denied.
5. `05-helpdesk-reset-success.png` - Noah's delegated password reset succeeds.
6. `06-helpdesk-disable-denied.png` - Noah's disable attempt returns Access Denied.
7. `07-mevans-disabled.png` - Mia in Disabled OU with description stamp.
8. `08-access-report.png` - generated access report.
9. `09-rdp-port-failed.png` - TCP 3389 failed while firewall rule disabled.
10. `10-rdp-port-passed.png` - TCP 3389 succeeds after rule re-enabled.

Optional Entra screenshots:
11. MFA registration prompt.
12. `SG-FrontDesk` enterprise application assignment.
13. Helpdesk Administrator role assignment.
14. Azure `rg-lab` Reader assignment at resource-group scope.

## Security notes
- Temporary passwords are printed only to the console and are never written to the lifecycle log.
- Helpdesk receives delegated rights only on the lab Users OU.
- Resource permissions are assigned to domain-local groups, not directly to users.
- Access outside a user's business role is escalated instead of granted by Tier 1.
- Offboarding disables accounts before any deletion to preserve auditability.

## Interview talking points
**Why AGDLP?** It separates business roles from resource permissions. Users change role-group membership while ACLs remain stable and access reviews stay understandable.

**Why disable before delete?** Disabling immediately blocks access while preserving the object, SID history, mailbox/data references, and audit trail during the retention period.

**Why delegate helpdesk rights instead of using Domain Admin?** Delegation limits the blast radius of credential compromise and gives support staff only the permissions required for their job.

## Resume-ready bullets
**Identity & Access Lifecycle Lab | Active Directory, PowerShell, Microsoft 365, Entra ID**
- Built a Windows Server Active Directory domain and automated CSV-driven onboarding, password resets, access reviews, and offboarding with PowerShell and audit logging.
- Designed role-based access using AGDLP group nesting and delegated password-reset/unlock rights to a Helpdesk group, validating least privilege through successful and denied permission tests.
- Documented Microsoft 365 / Entra identity operations covering mailbox delegation, MFA, SSO, admin roles, Azure RBAC, and support-ticket troubleshooting and escalation.

## Publishing checklist
- [ ] Replace sample output placeholders with files generated by the live lab.
- [ ] Add the required screenshots.
- [ ] Verify screenshots contain no temporary passwords.
- [ ] Verify `lifecycle.log` contains no passwords or sensitive data.
- [ ] Push the repository as `ad-identity-lifecycle-lab`.
- [ ] Add the GitHub URL to the project section of your resume.
