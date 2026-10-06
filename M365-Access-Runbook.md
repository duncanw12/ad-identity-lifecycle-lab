# Microsoft 365 / Entra ID Access Runbook

## Purpose
This runbook documents the cloud-side identity lifecycle that complements the on-premises Active Directory lab. It covers mailbox delegation, MFA, SSO, cloud roles, Azure RBAC, and leaver handling using least-privilege principles.

## Identity concepts

### Authentication vs. authorization
Authentication proves who a user is, such as signing in with a password and MFA. Authorization determines what that authenticated user is allowed to access, usually through groups, roles, and permissions.

### MFA
Multi-factor authentication adds another proof of identity beyond a password. In a small tenant, Security Defaults can enforce MFA broadly; in larger environments, Conditional Access policies provide more granular controls, especially for privileged accounts.

### SSO
Single sign-on lets a user authenticate once with Entra ID and access multiple connected applications. SAML and OpenID Connect are common federation protocols. Access should normally be assigned to groups rather than individual users.

### Hybrid identity
In a hybrid environment, Microsoft Entra Connect can synchronize identities from on-premises AD to Entra ID. This provides a consistent identity across local and cloud resources while allowing lifecycle actions to originate from the authoritative directory.

### Least privilege for administrators
Helpdesk staff should receive only the role required to perform their job, such as Helpdesk Administrator or Password Administrator, instead of Global Administrator. This limits the blast radius if a privileged account is compromised.

## Mailbox delegation - Exchange Online PowerShell

### Full Access
Allows a user to open and read another mailbox.

```powershell
Add-MailboxPermission -Identity frontdesk@lab.com -User abrooks -AccessRights FullAccess -AutoMapping $true
```

### Send As
Allows a user to send mail that appears to come directly from the mailbox.

```powershell
Add-RecipientPermission -Identity frontdesk@lab.com -Trustee abrooks -AccessRights SendAs
```

### Send on Behalf
Allows a user to send mail showing that they sent it on behalf of the mailbox.

```powershell
Set-Mailbox frontdesk@lab.com -GrantSendOnBehalfTo @{Add='abrooks'}
```

### Convert a leaver mailbox to shared
Preserves the mailbox for business continuity while allowing the license to be removed when appropriate.

```powershell
Set-Mailbox mevans@lab.com -Type Shared
```

## Entra ID administration

### Tenant, subscription, and resource group
- **Tenant:** the Entra ID directory containing identities, groups, applications, and directory roles.
- **Subscription:** the Azure billing and resource-management boundary.
- **Resource group:** a logical container for related Azure resources.

### Entra roles vs. Azure RBAC
Entra roles such as Helpdesk Administrator and User Administrator control directory functions. Azure RBAC roles such as Owner, Contributor, and Reader control access to Azure resources. They are separate authorization systems.

### Least privilege in Azure
Assign the narrowest role at the narrowest scope possible. Prefer assigning roles to groups rather than individual users, and avoid subscription-wide permissions when resource-group scope is enough.

## Joiner checklist - cloud
1. Create or synchronize the user account.
2. Assign the user to approved security groups.
3. Assign only required Microsoft 365 licenses.
4. Require MFA registration.
5. Assign enterprise applications through group membership.
6. Validate the user can access only approved resources.
7. Record the request or ticket that authorized access.

## Access change checklist
1. Verify requester identity and business approval.
2. Check current groups and assigned roles.
3. Add or remove access through groups whenever possible.
4. Avoid direct user permissions unless the platform requires them.
5. Test effective access after the change.
6. Document exactly what changed and why.

## Leaver checklist - cloud
1. Block sign-in.
2. Revoke active sessions.

```powershell
Revoke-MgUserSignInSession -UserId <user-id>
```

3. Remove licenses and unnecessary group memberships.
4. Convert the mailbox to shared or configure manager-approved forwarding when required.
5. Remove MFA methods and registered devices according to policy.
6. Remove privileged roles and application assignments.
7. Preserve required business data and audit history.
8. Record the offboarding ticket and completion time.

## Optional Entra/Azure lab proof
If a free Entra tenant is available:
1. Create `ava.brooks`.
2. Create `SG-FrontDesk` and add Ava.
3. Enable Security Defaults and capture the MFA registration prompt.
4. Assign a second test user the Helpdesk Administrator role and explain why Global Administrator is unnecessary.
5. Add a gallery enterprise application and assign `SG-FrontDesk`.
6. Create `rg-lab` in Azure and assign `SG-FrontDesk` the Reader role at only that resource group.
7. Capture screenshots showing the group assignment, SSO page, MFA prompt, directory role, and Azure RBAC assignment.
