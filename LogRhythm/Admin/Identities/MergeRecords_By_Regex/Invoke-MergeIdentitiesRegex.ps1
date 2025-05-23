using namespace System.Collections.Generic
# Start Transcript
Start-Transcript

# Change this to $false if you want to actually merge some identities.  
# It is recommended to review the output of this with this setting set to $true before settting this to false.  :)
$TestMode = $true

# Retrieve all TrueIdentities from LogRhythm's TrueIdentity API service
$Identities = Get-LrIdentities

# Set Admin account naming convention(s) based on Regex
$AdminPatterns = @('ADM-*', 'ADMS-*', 'ADMW-*', 'ADMC-*', '*_admin', '*_adm')
$AdminIdentities = [list[object]]::new()

# This is an array of values where the nameFirst is not empty
# And contains the unique representation of users who have more than one record
ForEach ($Pattern in $AdminPatterns) {
    $AdminMatches = $Identities | Where-Object {$_.identifiers.value -like $Pattern}
    ForEach ($AdminMatch in $AdminMatches) {
        if ($AdminIdentities -notcontains $AdminMatch) {
            $AdminIdentities.Add($AdminMatch)
        }
    }
}
if ($TestMode) {
    write-host "$(Get-Timestamp) - Operating in TEST MODE.  No Identities will be merged."
}
Write-Host "$(Get-Timestamp) - Loaded Identities: $($Identities.Count)"
Write-Host "$(Get-Timestamp) - Begin Evaluating Identities"
Write-Host "$(Get-Timestamp) - Evaluation Criteria for Admin accounts: $AdminPatterns"
Write-Host "$(Get-Timestamp) - Loaded Admin Identities: $($AdminIdentities.Count)"
# Iterate through Identities located in CSV to merge TrueIdentity Records.
:Identity ForEach ($AdminIdentity in $AdminIdentities) {
    Write-Host "$(Get-Timestamp) - Begin - IdentityId: $($AdminIdentity.identityId) NameFirst: $($AdminIdentity.NameFirst) NameLast: $($AdminIdentity.NameLast)"
    ForEach ($Pattern in $AdminPatterns) {
        ForEach ($Identifier in $AdminIdentity.Identifiers) {
            if ($Identifier.Value -like $Pattern) {
                $ReplacePattern = $Pattern.replace('*','')
                Write-Host "$(Get-Timestamp) - Removing $ReplacePattern from $($Identifier.Value)"
                $SearchIdentifier = $Identifier.Value.replace($ReplacePattern,'')

                # Remove the last character from the SearchIdentifier
                $SearchIdentifier = $SearchIdentifier
                Write-Host "$(Get-Timestamp) - SearchIdentifier: $SearchIdentifier"

                $IdentitySearchbyIdentifier = Get-LrIdentities -Identifier $($SearchIdentifier) -Exact
                if ($IdentitySearchbyIdentifier) {
                    if ($IdentitySearchbyIdentifier.identityID -ne $AdminIdentity.identityId) {
                        if ($IdentitySearchbyIdentifier.Count -gt 1) {
                            Write-Host "$(Get-Timestamp) - Returned Multple Identities based on Identifier Search.  Identities: $($IdentitySearchbyIdentifier.IdentityId)"
                        } else {
                           Write-Host "$(Get-Timestamp) - Standard Identity Id: $($IdentitySearchbyIdentifier.identityId) Name: $($IdentitySearchbyIdentifier.NameFirst) $($IdentitySearchbyIdentifier.NameLast)"
                           Write-Host "$(Get-Timestamp) - Admin Identity Id: $($AdminIdentity.identityId) Name: $($AdminIdentity.NameFirst) $($AdminIdentity.NameLast)"
                           if ($TestMode) {
                                write-host "$(Get-Timestamp) - Operating in TestMode.  Fake submission to merge: Identity: $($AdminIdentity.identityId) into Identity: $($IdentitySearchbyIdentifier.identityId)"
                           } else {
                                $MergeStatus = Merge-LrIdentities -SourceIdentityId $($AdminIdentity.identityId) -DestinationIdentityId $($IdentitySearchbyIdentifier.identityId)
                           }
                           start-sleep 0.1
                           if ($MergeStatus) {
                                Write-Host "$(Get-Timestamp) - Identity: $($AdminIdentity.identityId) Unable to merge into Identity: $($IdentitySearchbyIdentifier.identityId)"
                                Write-Host "$(Get-Timestamp) - Error: $($MergeStatus.note)"
                            } else {
                                Write-Host "$(Get-Timestamp) - Identity: $($AdminIdentity.identityId) successfully merged into Identity: $($IdentitySearchbyIdentifier.identityId)"
                            }
                           break :Identity
                        }
                    }
                }
            }
        }
    }
    Write-Host ""
}
Stop-Transcript
