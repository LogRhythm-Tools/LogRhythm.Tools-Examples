using namespace System.Collections.Generic
[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 1)]
    [string] $OutputPath = "C:\LR.Tools\Examples\Lists\ADtoLists"
)
Import-Module LogRhythm.Tools
import-module ActiveDirectory

$LogRhythmListOwner = "LogRhythm Administrator"

# Produce script transcript at OutputFile folder location.
$OutputPath = Split-Path $OutputPath -Resolve
$TranscriptPath = $OutputPath+"\Transcript_ADGroupMemberstoLRLists_"+$(((get-date).ToUniversalTime()).ToString("yyyyMMddTHHmmssZ"))+".txt"
# Start Transcript
Start-Transcript -Path $TranscriptPath


$SyncList = [List[object]]::new()


# Here is a example object example with details
$ADGSync1 = [PSCustomObject]@{
    # Name is showcased in the audit log outlining what is being processed
    Name = "Friends of TAM"
    # The InputGroup should be the GroupName as it appears in Active Directory and is the source of the Users that will be populated in LogRhyhtm
    InputGroup = "SG_FOT"
    # The Output Identity is the output list name that will be created and maintained in LogRhythm with TrueIdentity values for the input group
    Output_IdentityListName = "LogRhythm - Friends of TAM - Identity"
    # The Output Login is the output list name that will be created and maintained in LogRhythm with Login values for the input group
    Output_LoginListName = "LogRhythm - Friends of TAM - Login"
}
$SyncList.add($ADGSync1)

# Example - CloudAI Monitored Identities
$ADGSync2 = [PSCustomObject]@{
    # Name is showcased in the audit log outlining what is being processed
    Name = "LogRhythm CloudAI Subscribed Users"
    # The InputGroup should be the GroupName as it appears in Active Directory and is the source of the Users that will be populated in LogRhyhtm
    InputGroup = "SG_LR_MonitoredIdentities"
    # The Output Identity is the output list name that will be created and maintained in LogRhythm with TrueIdentity values for the input group
    Output_IdentityListName = "CloudAI: Monitored Identities"
    # An Output_* groups can be set to $null.  When the name is set to $null the list will not be created or updated
    Output_LoginListName = $null
}
$SyncList.add($ADGSync2)

# Define the AD groups you want to populate into LogRhythm by this example Object.
$InfoSec = [PSCustomObject]@{
    Name = "Technical Account Managers"
    InputGroup = "TAM"
    Output_IdentityListName = "LogRhythm - TAM - Identity"
    Output_LoginListName = "LogRhythm - TAM - Login"
}
$SyncList.add($InfoSec)



$ListOwnerNumber = Get-LrUserNumber -User $LogRhythmListOwner
$ListOwnerNumbers = Get-LrUsers | Select-Object -ExpandProperty number
if (!$ListOwnerNumber) {

} else {
    Write-Host "$(Get-Timestamp) - Start - List Synchronization" -ForegroundColor Green -BackgroundColor Black
    ForEach ($List in $SyncList) {
        Write-Host "$(Get-Timestamp) - Start - Processing List: $($List.name)" -ForegroundColor Green -BackgroundColor Black
        Write-Host "$(Get-Timestamp) - Info - Source AD Group: $($List.InputGroup)" -ForegroundColor Green -BackgroundColor Black
        Write-Host "$(Get-Timestamp) - Info - Destination Identity List: $($List.Output_IdentityListName)" -ForegroundColor Green -BackgroundColor Black
        Write-Host "$(Get-Timestamp) - Info - Destination Login List: $($List.Output_LoginListName)" -ForegroundColor Green -BackgroundColor Black
        $SyncUserLogins = [List[string]]::new()
        $SyncUserIdentities = [List[int32]]::new()
        
        $ADUsers = Get-AdGroupMember $($List.InputGroup) -Recursive

        ForEach ($User in $ADUsers) {
            # Populate Login List
            $UserSamAccountName = $($User | Select-Object -ExpandProperty samaccountname)
            if ($SyncUserLogins -notcontains $UserSamAccountName) {
                $SyncUserLogins.add($UserSamAccountName)
                Write-Host "$(Get-Timestamp) - Info - UserLogin Sync - Adding SamAccountName: $($UserSamAccountName)" -ForegroundColor Green -BackgroundColor Black
            }
    
            # Populate Identity List
            $IdentityResults = Get-LrIdentities -Identifier $UserSamAccountName
            if ($IdentityResults) {
                $UserIdentityId = $($IdentityResults | Select-Object -ExpandProperty identityId)
                ForEach ($UserId in $UserIdentityId) {
                    if ($SyncUserIdentities -notcontains $UserId) {
                        $SyncUserIdentities.add($UserId)
                        Write-Host "$(Get-Timestamp) - Info - TrueIdentity Sync - Adding TrueIdentity ID: $($UserId)" -ForegroundColor Green -BackgroundColor Black
                    }
                }
            } else {
                Write-Host "$(Get-Timestamp) - Alert - TrueIdentity Sync - No Identity found for SamAccountName: $($UserSamAccountName)" -ForegroundColor Green -BackgroundColor Black
            }     
        }
        Write-Host "$(Get-Timestamp) - Info - AD Group Member Count: $($ADUsers.count)" -ForegroundColor Green -BackgroundColor Black
        Write-Host "$(Get-Timestamp) - Info - SamAccountName Count: $($SyncUserLogins.count)" -ForegroundColor Green -BackgroundColor Black

        if ($List.Output_LoginListName) {
            Write-Host "$(Get-Timestamp) - Info - Destination Login List: $($List.Output_LoginListName)" -ForegroundColor Green -BackgroundColor Black
            $LoginListStatus = Get-LrList -Name $($List.Output_LoginListName) -Exact
            if (!$LoginListStatus) {
                ForEach ($UserNumber in $ListOwnerNumbers) {
                    New-LrList -Name $($List.Output_LoginListName) -ShortDescription $($List.Name) -ListType "generalvalue" -UseContext "User" -ReadAccess "publicrestrictedadmin" -WriteAccess "publicrestrictedadmin" -Owner $UserNumber
                }
            }

            # Update Login List
            Write-Host "$(Get-Timestamp) - Begin - Synchronizing LogRhythm List: $($List.Output_LoginListName)"  -ForegroundColor Green -BackgroundColor Black
            $LoginSyncResults = Sync-LrListItems -Name $($List.Output_LoginListName) -Value $SyncUserLogins -PassThru
            Write-Host "$(Get-Timestamp) - End - Synchronizing LogRhythm List: $($List.Output_LoginListName) Value Count: $($LoginSyncResults.ValueCount)" -ForegroundColor Green -BackgroundColor Black
        }

        # Update Identity List
        if ($List.Output_IdentityListName) {
            Write-Host "$(Get-Timestamp) - Info - Identities Count: $($SyncUserIdentities.count)" -ForegroundColor Green -BackgroundColor Black
            Write-Host "$(Get-Timestamp) - Info - Destination Identity List: $($List.Output_IdentityListName)" -ForegroundColor Green -BackgroundColor Black
            $IdentityListStatus = Get-LrList -Name $($List.Output_IdentityListName) -Exact
            if (!$IdentityListStatus) {
                ForEach ($UserNumber in $ListOwnerNumbers) {
                    New-LrList -Name $($List.Output_IdentityListName) -ShortDescription $($List.Name) -ListType "identity" -UseContext "None" -ReadAccess "publicrestrictedadmin" -WriteAccess "publicrestrictedadmin" -Owner $UserNumber
                }
            }
            Write-Host "$(Get-Timestamp) - Begin - Synchronizing LogRhythm List: $($List.Output_IdentityListName)"  -ForegroundColor Green -BackgroundColor Black
            $IdentitySyncResults = Sync-LrListItems -Name $($List.Output_IdentityListName) -Value $SyncUserIdentities -PassThru
            Write-Host "$(Get-Timestamp) - End - Synchronizing LogRhythm List: $($List.Output_IdentityListName) Value Count: $($IdentitySyncResults.ValueCount)" -ForegroundColor Green -BackgroundColor Black
        }
    
        Write-Host "$(Get-Timestamp) - End - Processing List: $($List.name)" -ForegroundColor Green -BackgroundColor Black
    }
    Write-Host "$(Get-Timestamp) - End - List Synchronization" -ForegroundColor Green -BackgroundColor Black
}
