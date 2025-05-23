$Workstations = Get-ADComputer -Filter  {enabled -eq $true} -SearchBase "OU=Workstations,DC=EXAMPLE,DC=com" -Properties *

$TargetEntityId = 26

$DefaultOSType = 'Desktop'
$DefaultRisk = 'low-low'
$DefaultThreat = 'low-low'
$AdminAssetRisk = 'medium-medium'
$AdminAssetThreat = 'medium-medium'
$DefaultShortDescription = 'This host record was created by the SIEM administration team to facilitate automated management and visibility of assets in the LR SIEM.'

ForEach ($Workstation in $Workstations) {
    $HostRecordStatus = Get-LrHosts -Entity $TargetEntityId -Name $($Workstation.DNSHostName) -Exact

    if ($null -eq $HostRecordStatus) {
        Write-Host "$(Get-Timestamp) | Info | Create | Host Status | No LogRhythm Entity Host record found for name: $($Workstation.DNSHostName).  Proceeding to create new record."
        if ($Workstation.Description) {
            $ShortSummary = $($Workstation.Description).substring(0, [System.Math]::Min(254, $($Workstation.Description).Length))
        } else {
            Write-Host "$(Get-Timestamp) | Info | Create | ShortSummary | AD DNS Name: $($Workstation.DNSHostName) | No Description property defined on the host's Active Directory record.  Setting default."
            $ShortSummary = $DefaultShortDescription
        }

        if ($($($Workstation.DistinguishedName).Split(',')) -contains 'OU=All Admins') {
            $HostRisk = $AdminAssetRisk
            $HostThreat = $AdminAssetThreat
            Write-Host "$(Get-Timestamp) | Info | Create | Host Risk | AD DNS Name: $($Workstation.DNSHostName) | OU matches All Admins.  Updating HostRisk and HostThreat.  Risk: $HostRisk  Threat: $HostThreat"
        } else {
            $HostRisk = $DefaultRisk
            $HostThreat = $DefaultThreat
        }

        if ($null -eq $Workstation.OperatingSystem) {
            $Workstation.OperatingSystem = "Windows"
            Write-Host "$(Get-Timestamp) | Info | Create | OSVersion | AD DNS Name: $($Workstation.DNSHostName) | No OperatingSystem property defined for host.  Setting to default: Windows."
        }

        $NewHost = New-LrHost -Entity $TargetEntityId -Name $Workstation.DNSHostName -ShortDesc $ShortSummary -RecordStatus 'active' -Zone 'internal' -OSType $DefaultOSType -OS "Windows" -OSVersion $Workstation.OperatingSystem -RiskLevel $HostRisk -ThreatLevel $HostThreat -PassThru

        if ($NewHost.error) {
            # Error
            Write-Host "$(Get-Timestamp) | Error | Create | Create Host | AD DNS Name: $($Workstation.DNSHostName) | $($NewHost.Note)"
        } elseif ($null -ne $NewHost) {
            # Good  "DNSName" "WindowsName"
            Write-Host "$(Get-Timestamp) | Info | Create | Create Host | AD DNS Name: $($Workstation.DNSHostName) | Created LogRhythm record: $($NewHost.id)"
            $NewIdentifier_1 = Update-LrHostIdentifier -Id $NewHost.id -Type "WindowsName" -Value $Workstation.name -PassThru
            if ($NewIdentifier_1.error) {
                Write-Host "$(Get-Timestamp) | Error | Create | Create Identifier | AD DNS Name: $($Workstation.DNSHostName) | Type: WindowsName | $($NewIdentifier_1.Note)"
            } else {
                Write-Host "$(Get-Timestamp) | Info | Create | Create Identifier | AD DNS Name: $($Workstation.DNSHostName) | Type: WindowsName | Created identifier: $($Workstation.name )"
            }
            $NewIdentifier_2 = Update-LrHostIdentifier -Id $NewHost.id -Type "DNSName" -Value $Workstation.DNSHostName -PassThru
            if ($NewIdentifier_2.error) {
                Write-Host "$(Get-Timestamp) | Error | Create | Create Identifier | AD DNS Name: $($Workstation.DNSHostName) | Type: DNSName | $($NewIdentifier_2.Note)"
            } else {
                Write-Host "$(Get-Timestamp) | Info | Create | Create Identifier | AD DNS Name: $($Workstation.DNSHostName) | Type: DNSName | Created identifier: $($Workstation.DNSHostName)"
            }
        } else {
            # Error
            Write-Host "$(Get-TimeStamp) | Error | Create | AD DNS Name: $($Workstation.DNSHostName) | Submitted New-LrHost and returned no data or error."
        }
    } else {
        $UpdateHost = $false
        Write-Host "$(Get-Timestamp) | Info | Update | Host Status | Host record exists for AD name: $($Workstation.DNSHostName).  Host Record: $($HostRecordStatus.id)."
        
        # Check workstation description
        if ($Workstation.Description) {
            $ShortSummary = $($Workstation.Description).substring(0, [System.Math]::Min(254, $($Workstation.Description).Length))
        } else {
            $ShortSummary = $DefaultShortDescription
        }

        if ($HostRecordStatus.ShortDesc -notlike $ShortSummary) {
            $UpdateHost = $True
            Write-Host "$(Get-Timestamp) | Info | Update | ShortDesc | Host Record: $($HostRecordStatus.id) requires update for field: ShortDescription"
        }

        # Set default HostRisk / HostThreat
        $HostRisk = $DefaultRisk
        $HostThreat = $DefaultThreat

        # Check asset threat/risk level
        if ($($($Workstation.DistinguishedName).Split(',')) -contains 'OU=All Admins') {
            # Risk Level
            if ($HostRecordStatus.risklevel -notlike $AdminAssetRisk) {
                $HostRisk = $AdminAssetRisk
                $UpdateHost = $True
                Write-Host "$(Get-Timestamp) | Info | Update | HostRisk | Host Record: $($HostRecordStatus.id) update to AdminAssetRisk: $($AdminAssetRisk)"
            }
            # Threat Level
            if ($HostRecordStatus.threatlevel -notlike $AdminAssetThreat) {
                $HostThreat = $AdminAssetThreat
                $UpdateHost = $True
                Write-Host "$(Get-Timestamp) | Info | Update | HostThreat | Host Record: $($HostRecordStatus.id) update to AdminAssetThreat: $($AdminAssetThreat)"
            }
            
            
        } else {
            if ($HostRecordStatus.risklevel -notlike $DefaultRisk) {
                $HostRisk = $DefaultRisk
                $UpdateHost = $True
                Write-Host "$(Get-Timestamp) | Info | Update | HostRisk | Host Record: $($HostRecordStatus.id) update to DefaultRisk: $($DefaultRisk)"
            }
            if ($HostRecordStatus.threatlevel -notlike $DefaultThreat) {
                $HostThreat = $DefaultThreat
                $UpdateHost = $True
                Write-Host "$(Get-Timestamp) | Info | Update | HostThreat | Host Record: $($HostRecordStatus.id) update to DefaultThreat: $($DefaultThreat)"
            }
        }

        # OS Version
        if ($HostRecordStatus.osversion -notlike $Workstation.OperatingSystem) {
            if ($null -eq $Workstation.OperatingSystem) {
                $Workstation.OperatingSystem = "Windows"
            }
            $UpdateHost = $true
            Write-Host "$(Get-Timestamp) | Info | Update | OS Version | Host Record: $($HostRecordStatus.id) requires update for field: OsVersion"
        }

        if ($UpdateHost -eq $true) {
            Write-Host "$(Get-Timestamp) | Info | Update | Host Update | Update required for asset: $($Workstation.DNSHostName).  Host Record: $($HostRecordStatus.id)."
            $UpdatedHost = Update-LrHost -Entity $TargetEntityId -Id $HostRecordStatus.id -ShortDesc $ShortSummary -RecordStatus 'active' -Zone 'internal' -OSType $DefaultOSType -OS "Windows" -OSVersion $Workstation.OperatingSystem -RiskLevel $HostRisk -ThreatLevel $HostThreat -PassThru
            if ($UpdatedHost.error) {
                # Error
                Write-Host "$(Get-Timestamp) | Error | Update | Update Host | AD DNS Name: $($Workstation.DNSHostName) | $($UpdatedHost.Note)"
            } else {
                Write-Host "$(Get-Timestamp) | Info | Update | Update Host | Successfully updated record: $($HostRecordStatus.id)"
            }
        } else {
            Write-Host "$(Get-Timestamp) | Info | Update | Host Update | No update required for asset: $($Workstation.DNSHostName).  Host Record: $($HostRecordStatus.id)."
        }
    }
    start-sleep 0.1
}