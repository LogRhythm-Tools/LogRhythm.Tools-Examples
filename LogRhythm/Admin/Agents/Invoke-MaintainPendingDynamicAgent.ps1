Import-Module LogRhythm.Tools
$PendingAgents = Get-LrAgentsPending
# Leveraging the Pending Agent's hostname as a type of schema to qualify what is an in-scope asset.
$TargetPendingAgents = $PendingAgents | Where-Object -filterscript {$_.hostName -like "deskt-*" -or $_.hostName -like "lapt-*"}

# In-Scope Entity: Workstations
$TargetEntityName = "Workstations"
$TargetEntityId = 130
$TargetEntityFullName = "Example/Workstations"
$RetireEntity = "zRetired"
$RetireEntityId = 19
$DefaultRisk = 'low-high'
$DefaultThreat = 'low-high'
$FQDNPost = ".example.com"

ForEach ($PendingAgent in $TargetPendingAgents) {
    write-host "$(Get-Timestamp) | Info | Begin Record | Pending Agent Hostname: $($PendingAgent.hostName)"
    $AgentStatus = Get-LrAgentsAccepted -Name $($PendingAgent.hostName) -Exact
    if ($AgentStatus -and ($AgentStatus.count -eq 1)) {
        write-host "$(Get-Timestamp) | Info | Existing Agent Identified | Agent Entity: $($AgentStatus.hostEntity)  HostID: $($AgentStatus.hostId)"

        if ($AgentStatus.hostEntity -notlike $TargetEntityName) {
            $TargetConflictLookup = Get-LrHosts -Name $PendingAgent.hostName -Exact -Entity $TargetEntityName -RecordStatus 'all'
            if ($TargetConflictLookup) {
                $ShortSummary = "Last Update: $(Get-Timestamp)  Process: Workstation Agent Management Automation  Reason: Inactive host record.  Replaced by host with active System Monitor Agent record."
                $ClearConflictStatus = Update-LrHost -Id $TargetEntityConflictLookup.id -Name $($TargetConflictLookup+"_r_"+$(Get-Random -Maximum 10000)) -Entity $RetireEntityId -RecordStatus "retired" -ShortDesc $ShortSummary
            }
            
            if ($null -eq $ClearConflictStatus) {
                $ShortSummary = "Last Update: $(Get-Timestamp)  Process: Workstation Agent Management Automation  Reason: Moved to target entity $($TargetEntityFullName)."
                $UpdateAgentHost = Update-LrHost -Id $($AgentStatus.hostId) -Entity $TargetEntityId -RecordStatus "active" -ShortDesc $ShortSummary -PassThru
                if ($UpdateAgentHost.error) {
                    write-host "$(Get-Timestamp) | Error | Existing Agent Update | AgentID: $($AgentStatus.hostId) | HostID: $($AgentStatus.hostId) | Moved to Entity: $($UpdateAgentHost.entity.name)"
                } else {
                    write-host "$(Get-Timestamp) | Info | Existing Agent Update | AgentID: $($AgentStatus.hostId) | HostID: $($AgentStatus.hostId) | Moved to Entity: $($UpdateAgentHost.entity.name)"
                }
            }
            $ClearConflictStatus = $null
        }
    } elseif ($AgentStatus -and ($AgentStatus.count -gt 1)) {
        write-host "More than one agent record found."
        continue
    } 

    [object[]]$HostLookup = Get-LrHosts -Name $PendingAgent.hostName -Exact -RecordStatus 'active'
    if ($HostLookup.count -gt 1) {
        # More than one matching record
        ForEach ($HostRecord in $HostLookup) {
            if ($HostRecord.entity.name -notlike $TargetEntityFullName) {
                $AgentStatus = Get-LrAgentsAccepted -Name $($HostRecord.Name)
                if ($null -ne $AgentStatus) {
                    $AgentFilter = $AgentStatus | Where-Object -filterscript { $_.recordStatusName -like 'Active' -and $_.hostEntity -notlike $TargetEntityName }
                    if ($null -eq $AgentFilter) {
                        $ShortSummary = "Last Update: $(Get-Timestamp)  Process: Workstation Agent Management Automation  Reason: Inactive host record.  Replaced by host with active System Monitor Agent record."
                        $ErrCatch = Update-LrHost -Id $HostRecord.id -Name $($HostRecord.name+"_r_"+$(Get-Random -Maximum 10000)) -Entity $RetireEntityId -RecordStatus "retired" -ShortDesc $ShortSummary -PassThru
                        if ($ErrCatch.Error) {
                            write-host "$(Get-Timestamp) | Error | Retire Host | HostID: $($HostRecord.id) | Reason: $($ErrCatch.note)"
                        } else {
                            write-host "$(Get-Timestamp) | Info | Retire Host | Host: $($ErrCatch.id) | Moved to entity: $($ErrCatch.entity.name)"
                        }
                    }
                }
            }
        }
    }

    # Update HostLookup as the previous check can potentially resolve the conflicting records
    [object[]]$HostLookup = Get-LrHosts -Name $PendingAgent.hostName -Exact -RecordStatus 'active' -Entity $TargetEntityId
    if ($HostLookup.count -eq 1) {
        # One matching Record
        if ($HostLookup.entity.name -eq $TargetEntityFullName) {
            
            $HostIdentifiers = Get-LrHostIdentifiers -Id $($HostLookup.id)
            [string[]]$PendingIPv4Addresses = $PendingAgent.ipAddress.split("|")
            
            [string[]]$ActiveIPs = $HostIdentifiers | Where-Object -filterscript {$_.type -like "IPAddress" -and $null -eq $_.dateRetired} | Select-Object -ExpandProperty value
            if ($null -ne $ActiveIPs) {
                ForEach ($ActiveIP in $ActiveIPs) {
                    if ($PendingIPv4Addresses -notcontains $ActiveIP) {
                        $ErrCatch = remove-lrhostidentifier -id $($HostLookup.id) -type 'ipaddress' -value $ActiveIP
                        if ($ErrCatch.Error) {
                            write-host "$(Get-Timestamp) | Error | Identifier Remove | Host: $($HostLookup.id) | Identifier: $ActiveIP Type: IPAddress | $($ErrCatch.Note)"
                        } else {
                            write-host "$(Get-Timestamp) | Info | Identifier Remove | Host: $($HostLookup.id) | Identifier: $ActiveIP Type: IPAddress"
                        }
                    } else {
                        write-host "$(Get-Timestamp) | Info | Identifier Verified | Host: $($HostLookup.id) | Pending IP: $($PendingIPv4Addresses)  Current IP: $($ActiveIP)"
                    }
                }
            }
            # Refresh ActiveIPs
            [string[]]$ActiveIPs = $HostIdentifiers | Where-Object -filterscript {$_.type -like "IPAddress" -and $null -eq $_.dateRetired} | Select-Object -ExpandProperty value

            ForEach ($PendingIP in $PendingIPv4Addresses) {
                if ($ActiveIPs -notcontains $PendingIP) {
                    $ErrCatch = update-lrhostidentifier -id $($HostLookup.id) -type 'ipaddress' -value $PendingIP
                    if ($ErrCatch.Error) {
                        write-host "$(Get-Timestamp) | Error | Identifier Add | Host: $($HostLookup.id) | Identifier: $PendingIP Type: IPAddress | $($ErrCatch.Note)"
                    } else {
                        write-host "$(Get-Timestamp) | Info | Identifier Add | Host: $($HostLookup.id) | Identifier: $PendingIP Type: IPAddress"
                    }
                }
            }

            if ($HostIdentifiers) {
                $Hostnames = $HostIdentifiers | Where-Object -Property 'type' -like "WindowsName" | Where-Object -property 'dateRetired' -eq $null

                $FQDNs = $HostIdentifiers | Where-Object -Property 'type' -like 'DNSName' | Where-Object -property 'dateRetired' -eq $null
            }
        
            if ($null -ne $Hostnames) {
                if ($Hostnames.value -notcontains $($HostLookup.name)) {
                    $_hostname = $HostLookup.name
                } else {
                    $_hostname = $null
                }
            } else {
                $_hostname = $HostLookup.name
            }


            if ($null -ne $FQDNs) {
                $hostFQDN = $HostLookup.name + $FQDNPost
                if ($FQDNs.value -notcontains $hostFQDN) {
                    $_fqdn = $hostFQDN
                } else {
                    $_fqdn = $null
                }
            } else {
                $_fqdn = $hostFQDN
            }

            if ($null -ne $_hostname) {
                $ErrCatch = update-lrhostidentifier -id $($HostLookup.id) -type 'WindowsName' -value $_hostname
                if ($ErrCatch.Error) {
                    write-host "$(Get-Timestamp) | Error | Identifier Add | Host: $($HostLookup.id) | Identifier: $_hostname Type: WindowsName | $($ErrCatch.Note)"
                } else {
                    write-host "$(Get-Timestamp) | Info | Identifier Add | Host: $($HostLookup.id) | Identifier: $_hostname Type: WindowsName"
                }
            }

            if ($null -ne $_fqdn) {
                $ErrCatch = update-lrhostidentifier -id $($HostLookup.id) -type 'DnsName' -value $_fqdn
                if ($ErrCatch.Error) {
                    write-host "$(Get-Timestamp) | Error | Identifier Add | Host: $($HostLookup.id) | Identifier: $_fqdn Type: DnsName | $($ErrCatch.Note)"
                } else {
                    write-host "$(Get-Timestamp) | Info | Identifier Add | Host: $($HostLookup.id) | Identifier: $_fqdn Type: DnsName"
                }
            }
            
            # Add Host Record's Agent Record ID and plug into -AssociateAgentId
            $Agents = Get-LrAgentsAccepted -RecordStatus 'active'
            if ($Agents.hostId -contains $HostLookup.id) {
                $TargetAgentId = $Agents | Where-Object -FilterScript {$_.hostId -eq $HostLookup.id} | Select-Object -ExpandProperty id
                if ($null -ne $TargetAgentId)
                {
                    Update-LrAgentPending -Entity $HostLookup.entity.name -AcceptanceStatus 'associate' -AssociateAgentId $TargetAgentId -Guid $PendingAgent.Guid
                }
            }
        }
    } else {
        # No Agent, new agent
        write-host "$(Get-Timestamp) | Info | Create Host | Hostname: $($PendingAgent.hostName) does not exist in entity $($TargetEntityName)"
        $ShortSummary = "Last Update: $(Get-Timestamp)  Process: Workstation Agent Management Automation  Reason: Created new host record."
        $NewHost = New-LrHost -Entity $TargetEntityId -Name $PendingAgent.hostName -ShortDesc $ShortSummary -RecordStatus 'active' -Zone 'internal' -OSType "Desktop" -OS "Windows" -OSVersion $PendingAgent.osVersion -RiskLevel $DefaultRisk -ThreatLevel $DefaultThreat -PassThru
        
        if ($NewHost.error) {
            write-host "$(Get-Timestamp) | Error | Create Host | Hostname: $($PendingAgent.hostName) | $($NewHost.Note)"
        } else {
            [string[]]$NewIPv4 = $PendingAgent.ipAddress.split("|")
            ForEach ($IPAddress in $NewIPv4) {
                $ErrCatch = update-lrhostidentifier -id $($NewHost.id) -type 'ipaddress' -value $IPAddress
                if ($ErrCatch.Error) {
                    write-host "$(Get-Timestamp) | Error | Add Identifier | Host: $($($NewHost.id)) | Identifier: $($PendingAgent.hostName) Type: IPAddress | $($ErrCatch.Note)"
                } else {
                    write-host "$(Get-Timestamp) | Info | Add Identifier | Host: $($($NewHost.id)) | Identifier: $($PendingAgent.hostName) Type: IPAddress"
                }
            }

            $ErrCatch = update-lrhostidentifier -id $($NewHost.id) -type 'WindowsName' -value $PendingAgent.hostName
            if ($ErrCatch.Error) {
                write-host "$(Get-Timestamp) | Error | Add Identifier | Host: $($($NewHost.id)) | Identifier: $($PendingAgent.hostName) Type: WindowsName | $($ErrCatch.Note)"
            } else {
                write-host "$(Get-Timestamp) | Info | Add Identifier | Host: $($($NewHost.id)) | Identifier: $($PendingAgent.hostName) Type: WindowsName"
            }

            $hostFQDN = $PendingAgent.hostName + $FQDNPost
            $ErrCatch = update-lrhostidentifier -id $($NewHost.id) -type 'DnsName' -value $hostFQDN
            if ($ErrCatch.Error) {
                write-host "$(Get-Timestamp) | Error | Identifier Add | Host: $($NewHost.id) | Identifier: $hostFQDN Type: DnsName | $($ErrCatch.Note)"
            } else {
                write-host "$(Get-Timestamp) | Info | Identifier Add | Host: $($NewHost.id) | Identifier: $hostFQDN Type: DnsName"
            }
        }
    }
    write-host "$(Get-Timestamp) | Info | End Record | Pending Agent Hostname: $($PendingAgent.hostName)"
}