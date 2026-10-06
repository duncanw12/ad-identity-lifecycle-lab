#Requires -Modules ActiveDirectory

$Domain   = Get-ADDomain
$DomainDN = $Domain.DistinguishedName
$LabOU    = "OU=Lab,$DomainDN"
$LogFile  = ".\lifecycle.log"

function Write-Log {
    param([Parameter(Mandatory)][string]$Msg)
    $line = "$(Get-Date -Format s) [$env:USERNAME] $Msg"
    Add-Content -Path $LogFile -Value $line
    Write-Host $line
}

function New-TempPassword {
    $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789'
    $random = -join (1..12 | ForEach-Object {
        $chars[(Get-Random -Maximum $chars.Length)]
    })
    return ($random + 'Aa1!')
}

function Ensure-ADGroupMembership {
    param(
        [Parameter(Mandatory)][string]$Group,
        [Parameter(Mandatory)][string]$Member
    )

    $isMember = Get-ADGroupMember -Identity $Group -Recursive |
        Where-Object { $_.SamAccountName -eq $Member -or $_.Name -eq $Member }

    if (-not $isMember) {
        Add-ADGroupMember -Identity $Group -Members $Member
    }
}

function New-LabStructure {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq 'Lab'" -SearchBase $DomainDN -SearchScope OneLevel -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name 'Lab' -Path $DomainDN -ProtectedFromAccidentalDeletion $false
    }

    foreach ($ou in 'Users','Groups','Disabled') {
        if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -SearchBase $LabOU -SearchScope OneLevel -ErrorAction SilentlyContinue)) {
            New-ADOrganizationalUnit -Name $ou -Path $LabOU -ProtectedFromAccidentalDeletion $false
        }
    }

    $grpOU = "OU=Groups,$LabOU"

    foreach ($g in 'GG_FrontDesk','GG_OfficeManager','GG_Helpdesk') {
        if (-not (Get-ADGroup -Filter "Name -eq '$g'" -ErrorAction SilentlyContinue)) {
            New-ADGroup -Name $g -GroupScope Global -GroupCategory Security -Path $grpOU
        }
    }

    foreach ($g in 'DL_Schedules_Read','DL_Finance_Modify') {
        if (-not (Get-ADGroup -Filter "Name -eq '$g'" -ErrorAction SilentlyContinue)) {
            New-ADGroup -Name $g -GroupScope DomainLocal -GroupCategory Security -Path $grpOU
        }
    }

    Ensure-ADGroupMembership -Group 'DL_Schedules_Read' -Member 'GG_FrontDesk'
    Ensure-ADGroupMembership -Group 'DL_Schedules_Read' -Member 'GG_OfficeManager'
    Ensure-ADGroupMembership -Group 'DL_Finance_Modify' -Member 'GG_OfficeManager'

    # Least privilege: Helpdesk may reset passwords, force password change at logon,
    # and unlock accounts in the Lab Users OU, but receives no broader admin rights.
    $usersOU = "OU=Users,$LabOU"
    $nb = $Domain.NetBIOSName

    dsacls $usersOU /I:S /G "$nb\GG_Helpdesk:CA;Reset Password;user" | Out-Null
    dsacls $usersOU /I:S /G "$nb\GG_Helpdesk:RPWP;pwdLastSet;user" | Out-Null
    dsacls $usersOU /I:S /G "$nb\GG_Helpdesk:RPWP;lockoutTime;user" | Out-Null

    Write-Log 'Lab OUs, groups, AGDLP nesting, and helpdesk delegation created'
}

function Add-LabUser {
    param([string]$CsvPath = '.\new-hires.csv')

    foreach ($u in Import-Csv -Path $CsvPath) {
        $sam = ($u.FirstName.Substring(0,1) + $u.LastName).ToLower()

        if (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue) {
            Write-Log "SKIP $sam exists"
            continue
        }

        $roleGroup = "GG_$($u.Role)"
        if (-not (Get-ADGroup -Identity $roleGroup -ErrorAction SilentlyContinue)) {
            throw "Role '$($u.Role)' does not map to an existing group '$roleGroup'."
        }

        $pw = New-TempPassword

        New-ADUser `
            -Name "$($u.FirstName) $($u.LastName)" `
            -GivenName $u.FirstName `
            -Surname $u.LastName `
            -SamAccountName $sam `
            -UserPrincipalName "$sam@$($Domain.DNSRoot)" `
            -Title $u.Role `
            -Office $u.Office `
            -Path "OU=Users,$LabOU" `
            -AccountPassword (ConvertTo-SecureString $pw -AsPlainText -Force) `
            -Enabled $true `
            -ChangePasswordAtLogon $true

        Add-ADGroupMember -Identity $roleGroup -Members $sam

        Write-Log "CREATED $sam role=$($u.Role) (temporary password issued; change required at logon)"
        Write-Host "Temp password for ${sam}: $pw" -ForegroundColor Yellow
        # Lab only: never write temporary passwords to the log.
    }
}

function Reset-LabPassword {
    param(
        [Parameter(Mandatory)][string]$Sam,
        [string]$Ticket = 'N/A'
    )

    $pw = New-TempPassword

    Set-ADAccountPassword -Identity $Sam -Reset -NewPassword (ConvertTo-SecureString $pw -AsPlainText -Force)
    Set-ADUser -Identity $Sam -ChangePasswordAtLogon $true

    $user = Get-ADUser -Identity $Sam -Properties LockedOut
    if ($user.LockedOut) {
        Unlock-ADAccount -Identity $Sam
    }

    Write-Log "RESET $Sam ticket=$Ticket"
    Write-Host "Temp password for ${Sam}: $pw" -ForegroundColor Yellow
}

function Disable-LabUser {
    param(
        [Parameter(Mandatory)][string]$Sam,
        [string]$Ticket = 'N/A'
    )

    $user = Get-ADUser -Identity $Sam -Properties MemberOf
    $groups = @($user.MemberOf | ForEach-Object { (Get-ADGroup -Identity $_).Name })

    Disable-ADAccount -Identity $Sam

    foreach ($g in $user.MemberOf) {
        Remove-ADGroupMember -Identity $g -Members $Sam -Confirm:$false
    }

    $stamp = "Disabled $(Get-Date -Format yyyy-MM-dd) ticket=$Ticket; prior groups: $($groups -join ', ')"
    Set-ADUser -Identity $Sam -Description $stamp
    Move-ADObject -Identity $user.DistinguishedName -TargetPath "OU=Disabled,$LabOU"

    Write-Log "DISABLED $Sam ticket=$Ticket removed from: $($groups -join ', ')"
}

function Get-LabAccessReport {
    Get-ADUser -Filter * -SearchBase $LabOU -Properties Enabled,Title,MemberOf,LastLogonDate,whenCreated |
        Select-Object Name,SamAccountName,Enabled,Title,whenCreated,LastLogonDate,
            @{Name='Groups';Expression={
                ($_.MemberOf | ForEach-Object { ($_ -split ',')[0] -replace '^CN=' }) -join '; '
            }},
            @{Name='Stale';Expression={
                -not $_.LastLogonDate -or $_.LastLogonDate -lt (Get-Date).AddDays(-30)
            }} |
        Export-Csv -Path '.\access-report.csv' -NoTypeInformation

    Write-Log 'Access report exported'
}
