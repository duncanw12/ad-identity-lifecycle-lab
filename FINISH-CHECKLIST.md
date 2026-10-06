# Finish Checklist

## Phase 1 - Domain lab
- [ ] Windows Server 2025 VM running as `DC01`
- [ ] Static IP `192.168.50.10/24`
- [ ] Domain `lab.local` created
- [ ] RDP enabled
- [ ] Clean DC checkpoint created

## Phase 2 - Identity lifecycle
- [ ] Copy `IdentityLifecycle.ps1` and `new-hires.csv` to `C:\Lab`
- [ ] Dot-source the script
- [ ] Run `New-LabStructure`
- [ ] Run `Add-LabUser`
- [ ] Create Schedules and Finance SMB shares
- [ ] Verify AGDLP nesting
- [ ] Verify Effective Access for Liam and Ava
- [ ] Prove Noah can reset a password
- [ ] Prove Noah cannot disable an account

## Phase 3 - Tickets
- [ ] INC1001 lockout/reset completed
- [ ] INC1003 RDP firewall failure/resolution completed
- [ ] REQ2001 Mia offboarded
- [ ] REQ2002 Send As documented
- [ ] REQ2003 Finance request escalated
- [ ] `Get-LabAccessReport` run

## Phase 4 - Portfolio evidence
- [ ] Copy `access-report.csv` into `sample-output/`
- [ ] Copy `lifecycle.log` into `sample-output/`
- [ ] Add required screenshots
- [ ] Remove all temporary passwords from evidence
- [ ] Review README
- [ ] Push to GitHub
- [ ] Add repo URL to resume
