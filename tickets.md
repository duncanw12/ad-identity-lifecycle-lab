# Identity & Access Lifecycle Lab - Support Tickets

## Troubleshooting workflow
1. Verify the caller's identity before changing the account.
2. Gather the symptoms, exact error, recent changes, and scope.
3. Confirm the problem with data such as `Get-ADUser`, `Test-NetConnection`, Event Viewer, or Effective Access.
4. Isolate the cause, apply only changes within Tier 1 permissions, and test the result.
5. Escalate when the request requires higher privileges, business approval, or could affect multiple users. Include a complete handoff.
6. Document the resolution and a prevention note before closing.

---

## INC1001 - Ava Brooks account lockout
- **Reported:** User reports she cannot sign in after returning from vacation.
- **Priority:** P3
- **Identity verified:** Callback to number on file.
- **User:** `LAB\abrooks`
- **Initial checks:** Reviewed `LockedOut` and `BadLogonCount` using `Get-ADUser`.
- **Finding:** Account was locked after repeated failed authentication attempts.
- **Action:** Reset password with `Reset-LabPassword -Sam abrooks -Ticket INC1001`; account was unlocked and configured to require password change at next logon.
- **Validation:** Confirmed account was no longer locked and user was instructed to sign in with the temporary password and set a new password.
- **Prevention:** User advised to update any saved credentials on devices or applications if lockouts repeat.
- **Status:** Resolved.

## INC1003 - RDP connection failure
- **Reported:** Ava cannot connect to `DC01` over Remote Desktop.
- **Priority:** P3
- **Identity verified:** Callback to number on file.
- **Scope:** One server; network reachability available.
- **Checks:**
  - `Test-NetConnection 192.168.50.10` showed host reachable.
  - `Test-NetConnection 192.168.50.10 -Port 3389` failed.
  - `Get-Service TermService` confirmed the RDP service was available.
  - `Get-NetFirewallRule -DisplayGroup "Remote Desktop"` showed the firewall rules disabled.
- **Finding:** TCP/3389 was blocked by the Windows Firewall because the Remote Desktop rule group was disabled.
- **Action:** Ran `Enable-NetFirewallRule -DisplayGroup "Remote Desktop"`.
- **Validation:** Re-ran `Test-NetConnection 192.168.50.10 -Port 3389`; test passed and RDP connectivity was restored.
- **Troubleshooting order used:** Network -> port -> service -> firewall -> account.
- **Prevention:** Document firewall changes and verify RDP rules after security-policy changes.
- **Status:** Resolved.

## REQ2001 - Mia Evans offboarding
- **Reported:** Manager states Mia Evans' last day is today.
- **Priority:** P2 / scheduled access removal
- **Approval:** Manager-authorized offboarding request.
- **User:** `LAB\mevans`
- **Initial checks:** Reviewed current AD account and group memberships.
- **Action:** Ran `Disable-LabUser -Sam mevans -Ticket REQ2001`.
- **Result:** Account disabled, role-group memberships removed, prior groups stamped into the AD description, and the user moved to the `Disabled` OU.
- **Cloud follow-up:** Block sign-in, revoke sessions, remove licenses/groups, preserve or convert mailbox according to manager request, remove MFA methods/devices, and remove privileged assignments.
- **Validation:** Confirmed account disabled and located in the Disabled OU.
- **Prevention:** Use a standardized joiner/mover/leaver checklist tied to a ticket number.
- **Status:** Resolved.

## REQ2002 - Liam Carter Send As request
- **Reported:** Liam needs to send messages as the Front Desk shared mailbox.
- **Priority:** P4
- **Identity verified:** Requester identity verified.
- **Approval:** Manager approval required and recorded before change.
- **Requested permission:** Send As on `frontdesk@lab.com`.
- **Action after approval:**

```powershell
Add-RecipientPermission -Identity frontdesk@lab.com -Trustee lcarter -AccessRights SendAs
```

- **Reasoning:** Send As is the narrow permission matching the business requirement; Full Access is not automatically granted because it would provide unnecessary mailbox access.
- **Validation:** In production, test by sending a message from the shared mailbox and verify the From field shows the shared mailbox.
- **Prevention:** Grant mailbox permissions only after documented business approval and review them periodically.
- **Status:** Resolved after approval / simulated in written runbook because Exchange Online is not deployed in the lab.

## REQ2003 - Ava Brooks Finance share access
- **Reported:** User requests access to `\\DC01\Finance` to view invoices.
- **Priority:** P4
- **Identity verified:** Callback to number on file.
- **Checks:** `abrooks` is a member of `GG_FrontDesk` only; Effective Access on the Finance folder shows denied as expected.
- **Finding:** Finance access is assigned through `DL_Finance_Modify`, which receives membership from `GG_OfficeManager`. Ava's Front Desk role does not authorize Finance access.
- **Action:** No permission change made at Tier 1.
- **Escalated to:** Tier 2 / Office Manager, Liam Carter, for business approval and role validation.
- **Handoff notes:** Current groups checked, Effective Access screenshot attached, no changes made.
- **Least-privilege rationale:** Adding Ava directly to the resource group or changing ACLs would bypass the role model.
- **Status:** Pending approval / escalated.
