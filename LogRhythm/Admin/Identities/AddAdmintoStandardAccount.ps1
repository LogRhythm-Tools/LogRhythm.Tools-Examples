[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 0)]
    [System.IO.FileInfo] $InputFile = "C:\LR.Tools\Examples\TrueID\Input_TrueID_Merge_PrivID_to_SamAccountID.csv",

    [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 1)]
    [string] $OutputFile = "C:\LR.Tools\Examples\TrueID\Output_TrueID_Merge_PrivID_to_SamAccountID"
)

Import-Module LogRhythm.Tools

# Produce script transcript at OutputFile folder location.
$OutputPath = Split-Path $OutputFile -Parent
$TranscriptPath = $OutputPath+"\Transcript_AddAdmintoStandardAccount_"+$(((get-date).ToUniversalTime()).ToString("yyyyMMddTHHmmssZ"))+".txt"
# Start Transcript
Start-Transcript -Path $TranscriptPath

# Define ExportCSV Path
$ExportCsv = $OutputFile+"_"+$(((get-date).ToUniversalTime()).ToString("yyyyMMddTHHmmssZ"))+"_.csv"


# Import in TrueIdentitie source CSV
$Identities = Import-Csv -Path $InputFile | Select-Object -Skip 1

# Iterate through Identities located in CSV to merge TrueIdentity Records.
ForEach ($Identity in $Identities) {
    Write-Host "$(Get-Timestamp) - Begin - New Record - Name: $($Identity.NameFirst) $($Identity.NameLast) SamAccountName: $($Identity.SamAccountName) PrivSamAccountName: $($Identity.Privileged_SamAccountName)"
    Write-Verbose "$(Get-TimeSTamp) - Start - Evaluate Privileged_SamAccountName Duplicates"
    $PrivAccountCount = $Identities | Where-Object -Property Privileged_SamAccountName -eq $($Identity.Privileged_SamAccountName) | Measure-Object | Select-Object -ExpandProperty Count
    Write-Verbose "$(Get-TimeSTamp) - Info - Comparing Privileged_SamAccountName: $($Identity.Privileged_SamAccountName) Count: $PrivAccountCount"
    If ($PrivAccountCount -gt 1) {
        Write-Host "$(Get-TimeSTamp) - Error - Conflicting Privileged_SamAccountName Identified - Processing Record: $($Identity.SamAccountName)"
        # Duplicate Privileged_SamAccountName's identified
        $MergeNote = "Duplicate Privileged_SamAccountName's identified.  Privileged_SamAccountName's must be unique."      

        # Set the record's merge status to False.  Cannot merge the identities.
        $MergeStatus = "False"
    }
    Write-Verbose "$(Get-TimeSTamp) - End - Evaluate Privileged_SamAccountName Duplicates"
    
    Write-Verbose "$(Get-TimeSTamp) - Start - Evaluate SamAccountName Duplicates"
    
    $SamAccountCount = $Identities | Where-Object -Property SamAccountName -eq $($Identity.SamAccountName) | Measure-Object | Select-Object -ExpandProperty Count
    Write-Verbose "$(Get-TimeSTamp) - Info - Comparing SamAccountName: $($Identity.SamAccountName) Count: $SamAccountCount"
    If ($SamAccountCount -gt 1) {
        Write-Host "$(Get-TimeSTamp) - Error - Conflicting SamAccountName Identified - Processing Record: $($Identity.SamAccountName)"
        # Duplicate SamAccountName's identified
        $MergeNote = "Duplicate SamAccountName's identified.  SamAccountName's must be unique."      

        # Set the record's merge status to False.  Cannot merge the identities.
        $MergeStatus = "False"
    }
    Write-Verbose "$(Get-TimeSTamp) - End - Evaluate SamAccountName Duplicates"

    # Prevent processing if a duplicate was identified for the current record.
    if ($MergeStatus -ne "False") {
        # Retrieve the TrueID record based on the SamAccountName
        $UserTId = Find-LrIdentitySummaries -Login $Identity.SamAccountName
            
        if ($UserTId) {
            # SamAccountTrueID # - Update or create the Object record
            if ($Identity.SamAccountTrueID) {
                $Identity.SamAccountTrueID =  $UserTId.Id
            } else {
                $Identity | Add-Member -MemberType NoteProperty -Name SamAccountTrueID -Value $UserTId.Id -PassThru | Out-Null
            }

            $UserTIdStatus = Get-LrIdentityById -IdentityId $Identity.SamAccountTrueID 
            Write-Verbose "$(Get-Timestamp) - Info - User Identity: $($UserTIdStatus.Id) RecordStatus: $($UserTIdStatus.RecordStatus)"
            if ($UserTIdStatus -eq "Retired") {
                Write-Host "$(Get-Timestamp) - Update - Enabling User Identity: $($UserTIdStatus.Id)"
                $UserTIDEnableStatus = Enable-LrIdentity -IdentityId $UserTIdStatus.id
                Write-Host "$(Get-Timestamp) - Info - User Identity: $($UserTIdStatus.Id) RecordStatus: $($UserTIDEnableStatus.RecordStatus)"
            }
            # SamAccountTrueIDStatus - Update or create the Object record
            if ($Identity.SamAccountTrueIDStatus) {
                $Identity.SamAccountTrueIDStatus =  $UserTIdStatus.recordStatus
            } else {
                $Identity | Add-Member -MemberType NoteProperty -Name SamAccountTrueIDStatus -Value $UserTIdStatus.recordStatus -PassThru | Out-Null
            }
        }


        # Retrieve the TrueID record based on the Privileged_SamAccountName
        $AdminTId = Find-LrIdentitySummaries -Login $Identity.Privileged_SamAccountName


        if ($AdminTId) {
            if ($AdminTId.count -gt 1) {
                ForEach ($AdminID in $AdminTId) {
                    $TempAdminIDStatus = Get-LrIdentityById -IdentityId $AdminID.Id
                    if ($TempAdminIDStatus.recordstatus -eq "Active") {
                        $AdminTId = $AdminID
                    }
                }
            }

            # PrivilegedTrueID # - Update or create the Object record
            if ($Identity.PrivilegedTrueID) {
                $Identity.PrivilegedTrueID =  $AdminTId.Id
            } else {
                $Identity | Add-Member -MemberType NoteProperty -Name PrivilegedTrueID -Value $AdminTId.Id -PassThru | Out-Null
            }

            $AdminTIdStatus = Get-LrIdentityById -IdentityId $Identity.PrivilegedTrueID
            Write-Verbose "$(Get-Timestamp) - Info - Privileged User Identity: $($AdminTIdStatus.Id) RecordStatus: $($AdminTIdStatus.RecordStatus)"
            # PrivilegedTrueIDStatus - Update or create the Object record
            if ($Identity.PrivilegedTrueIDStatus) {
                $Identity.PrivilegedTrueIDStatus =  $AdminTIdStatus.recordStatus
            } else {
                $Identity | Add-Member -MemberType NoteProperty -Name PrivilegedTrueIDStatus -Value $AdminTIdStatus.recordStatus -PassThru | Out-Null
            }
        }



        # Verify we have a TrueID record for the User and the Privileged Account
        if (($null -ne $UserTId) -And ($null -ne $AdminTId)) {
            Write-Host "$(Get-Timestamp) - Info - User Identity: $($UserTId.Id) Admin Identity: $($AdminTId.Id)"
            if (($Identity.SamAccountTrueID -ne $Identity.PrivilegedTrueID) -and ($Identity.PrivilegedTrueIDStatus -ne "Retired") -and ($Identity.SamAccountTrueIDStatus -ne "Retired")) {
                $MergeIDResults = Merge-LrIdentities -PrimaryIdentity $Identity.SamAccountTrueID -SecondaryIdentity $Identity.PrivilegedTrueID -TestMode $false | Out-Null
                Start-Sleep 0.2
                $AdminTIdStatus = Get-LrIdentityById -IdentityId $Identity.PrivilegedTrueID
                Start-Sleep 0.2
                $UserTIdStatus = Find-LrIdentitySummaries -Login $Identity.Privileged_SamAccountName

                Write-Host "$(GEt-Timestamp) - Info - UserTIdStatus Count: $($UserTIdStatus.count)"
                if ($UserTIdStatus.count -gt 1) {
                    ForEach ($TempUserID in $UserTIdStatus) {
                        $TempUserIDStatus = Get-LrIdentityById -IdentityId $TempUserID.Id
                        if ($TempUserIDStatus.recordstatus -eq "Active") {
                            # PrivilegedTrueID # - Update or create the Object record
                            if ($TempUserIDStatus.Id -eq $Identity.SamAccountTrueID) {
                                $MergerIDVerdict = $true
                            }
                        }
                    }
                }

                Write-Host "$(Get-Timestamp) - Info - AdminTIdStatus: $($AdminTIdStatus.recordStatus)"
                if (($AdminTIdStatus.recordStatus -eq "Retired") -and ($MergerIDVerdict = $true)) {
                    Write-Host "$(Get-Timestamp) - Info - Merger verified."

                    # Set MergeStatus True
                    $MergeStatus = "True"

                    # PrivilegedTrueIDStatus - Update or create the Object record
                    if ($Identity.PrivilegedTrueIDStatus) {
                        $Identity.PrivilegedTrueIDStatus =  $AdminTIdStatus.recordStatus
                    } else {
                        $Identity | Add-Member -MemberType NoteProperty -Name PrivilegedTrueIDStatus -Value $AdminTIdStatus.recordStatus -PassThru | Out-Null
                    }

                    # Set MergeNote, Merge successful
                    $MergeNote = "TrueId merge successful.  Merger verified."  
                } else {
                    Write-Host "$(Get-Timestamp) - Error - Merger Error"
                    # MergeStatus # - Update or create the Object record
                    # Set MergeStatus True
                    $MergeStatus = "False"

                    # Set MergeNote, an unknown merger error occured.
                    $MergeNote = "An unknown merger error has occured.  Manually review record details."      
                }
            } else {
                # Previously synced
                Write-Host "$(Get-Timestamp) - Info - Identities previously synchronized.  No changes required."
                # Set MergeStatus True
                $MergeStatus = "True"

                # Set MergeNote, previously synchronized.
                $MergeNote = "Identities previously synchronized.  No changes required."      
            }
        } else {
            # Set MergeStatus False
            $MergeStatus = "False"

            if (!$AdminTId) {
                Write-Host "$(Get-Timestamp) - Error - Unable to locate TrueIdentity for Privileged_SamAccountName: $($Identity.SamAccountName)  NameFirst: $($Identity.NameFirst)  NameLast: $($Identity.NameLast)"
                # Set MergeNote No TrueID record found for the Privileged_SamAccountName
                $MergeNote = "No TrueID record found for the Privileged_SamAccountName"      
            }

            if (!$UserTId) {
                Write-Host "$(Get-Timestamp) - Error - Unable to locate TrueIdentity for SamAccountName: $($Identity.Privileged_SamAccountName)  NameFirst: $($Identity.NameFirst)  NameLast: $($Identity.NameLast)"

                # Set MergeNote No TrueID record found for the SamAccountName
                $MergeNote = "No TrueID record found for the SamAccountName"
            }
        } 
    } else {

    }

    # Update Merger Note
    if ($MergeNote) {
        if ($Identity.MergeNote) {
            $Identity.MergeNote =  $MergeNote
        } else {
            $Identity | Add-Member -MemberType NoteProperty -Name MergeNote -Value $MergeNote -PassThru | Out-Null
        }
    }

    # Update Merger Status
    if ($MergeStatus) {
        if ($Identity.MergeStatus) {
            $Identity.MergeStatus =  $MergeStatus
        } else {
            $Identity | Add-Member -MemberType NoteProperty -Name MergeStatus -Value $MergeStatus -PassThru | Out-Null
        }
    }


    # Update Merger timestamp
    # Add/Update $Identity.MergeDate
    if ($Identity.MergeDate) {
        $Identity.MergeDate =  $(Get-TimeStamp)
    } else {
        $Identity | Add-Member -MemberType NoteProperty -Name MergeDate -Value $(Get-TimeStamp) -PassThru | Out-Null
    }

    # Variable reset
    $UserTID = $null
    $AdminTId = $null
    $MergerIDVerdict = $null
    $UserTIdStatus = $null
    $TempAdminIDStatus = $null
    $AdminTIdStatus = $null
    $UserTIdStatus = $null
    $TempUserIDStatus = $null
    $MergeNote = $null
    $SamAccountCount = $null
    $PrivAccountCount = $null
    $MergeStatus = $null

    Write-Host "$(Get-Timestamp) - End - New Record - Name: $($Identity.NameFirst) $($Identity.NameLast) SamAccountName: $($Identity.SamAccountName) PrivSamAccountName: $($Identity.Privileged_SamAccountName)"
    Start-Sleep .2
}

$Identities | Export-Csv -Path $ExportCsv -NoTypeInformation
Stop-Transcript