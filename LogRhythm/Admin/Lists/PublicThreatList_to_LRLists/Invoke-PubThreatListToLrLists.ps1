using namespace System.Collections.Generic
[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 1)]
    [string] $OutputPath = "C:\LogRhythm.Tools\Examples\Lists\"
)
Import-Module LogRhythm.Tools

# Produce script transcript at OutputFile folder location.
$OutputPath = Split-Path $OutputPath -Resolve
$TranscriptPath = $OutputPath+"\Transcript_ThreatSync_"+$(((get-date).ToUniversalTime()).ToString("yyyyMMddTHHmmssZ"))+".txt"
# Start Transcript
Start-Transcript -Path $TranscriptPath


$SyncList = [List[object]]::new()

# Input Source = URL for txt content where each new line contains threat intel item
# Output_ThreatListName = LogRhythm List Name.  This field is limited to 50 characters
# Output_ThreatListName must be created before running this script.  This script synchronizes content into an EXISTING LR List.
$Log4J = [PSCustomObject]@{
    Input_Source = 'https://raw.githubusercontent.com/CriticalPathSecurity/Public-Intelligence-Feeds/master/log4j.txt'
    Output_ThreatListName = "LR Threat List : IP : CVE-2021-44228 - Apache Log4"
}
$SyncList.add($Log4J)

ForEach ($List in $SyncList) {
    Write-Host "$(Get-Timestamp) - Start - List Synchronization" -ForegroundColor Green -BackgroundColor Black
    Try {
        $ListContent = $(Invoke-RestMethod -Uri $List.Input_Source -Method 'Get' )
    } Catch {
        break
    }
    $ListArray = $($ListContent -Split "\n").Split('',[System.StringSplitOptions]::RemoveEmptyEntries)

    if ($ListArray) {
        Sync-LrListItems -Name $($List.Output_ThreatListName) -Value $ListArray -Verbose -PassThru
    }
}