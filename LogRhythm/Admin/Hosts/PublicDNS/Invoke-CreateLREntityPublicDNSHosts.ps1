$DNSHosts = Import-Csv -Path "C:\Users\eric.TAM\Documents\GitHub\LogRhythm.Tools-Examples\LogRhythm\Admin\Hosts\PublicDNS\PublicDNSServers.csv" -Header "name", "ip1", "ip2" | Select-Object -Skip 1

ForEach($DNSHost in $DNSHosts) {
    Write-Host "$(Get-TimeStamp) | Entity Enrichment | Create Public DNS Host Records | Begin | Service: $($DNSHost.name)"
    $HostStatus = get-lrhosts -Name $DNSHost.name -Exact
    if ($HostStatus -and !$HostStatus.Error) {
        $HostIdentifiers = Get-LrHostIdentifiers -Id $HostStatus.id
        if ($HostIdentifiers -and !$HostIdentifiers.Error) {
            $ExistingIPIdentifiers = $HostIdentifiers | Where-Object -FilterScript {$_.type -like 'IPAddress' -and $null -eq $_.dateRetired}
            if ($ExistingIPIdentifiers -notcontains $DNSHost.ip1) {
                Update-LrHostIdentifier -Id $HostStatus.id -Value $DNSHost.ip1 -Type 'IPAddress'
            }
            if ($DNSHost.ip2) {
                if ($ExistingIPIdentifiers -notcontains $DNSHost.ip2) {
                    Update-LrHostIdentifier -Id $HostStatus.id -Value $DNSHost.ip2 -Type 'IPAddress'
                }
            }
        } else {
            Update-LrHostIdentifier -Id $HostStatus.id -Value $DNSHost.ip1 -Type 'IPAddress'
            if ($DNSHost.ip2) {
                Update-LrHostIdentifier -Id $HostStatus.id -Value $DNSHost.ip2 -Type 'IPAddress'
            }
        }
    } elseif ($HostStatus.Error) {
        Write-Host $HostStatus
    } else {
        $HostCreateStatus = New-LrHost -Name $DNSHost.name -Entity 'Global Entity' -Zone 'External' -PassThru
        if ($HostCreateStatus.Error) {
            write-host $HostCreateStatus
        } else {
            Update-LrHostIdentifier -Id $HostCreateStatus.id -Value $DNSHost.ip1 -Type 'IPAddress'
            if ($DNSHost.ip2) {
                Update-LrHostIdentifier -Id $HostCreateStatus.id -Value $DNSHost.ip2 -Type 'IPAddress'
            }
        }
    }
    Write-Host "$(Get-TimeStamp) | Entity Enrichment | Create Public DNS Host Records | End | Service: $($DNSHost.name)"
    start-sleep 0.1
}