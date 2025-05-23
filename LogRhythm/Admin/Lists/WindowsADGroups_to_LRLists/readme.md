# Lists: Synchronize Microsoft Active Directory Group Members to LogRhythm Lists

# Overview
This example provides the means to Create and Maintain LogRhythm Lists based on Active Directory group membership.  This integration example performs a synchronization whereby the Active Directory group is the Source of Truth of all values that should be maintained on the LogRhythm List.  As members are added and/or removed from the Active Directory group the LogRhythm List contents will be paired to match the current state of the Active Directory group at the time the example code is executed.  This enables seamless management of LogRhythm List contents without the use of list value expiration settings.

This example is capable of creating two list types within the LogRhythm SIEM:
GeneralValue with the User context
Identity 

# Requirements
This inteigration example requires installation of LogRhythm.Tools and the Microsoft ActiveDirectory PowerShell module.

# Instructions
This example script requires setup before it can be applied.  It is recommended to perform testing with a subset of AD Groups prior to deploying as a production use case integration.

AD Group members are recursively queried.  This effectively ensures nested AD Groups and downstream group members are identified and added to the LogRhythm List(s).

## LogRhythm Owner
A critical component of this integration is to determine the LogRhythm List Owner for the lists the integration will create and maintain.  This must be updated in the script in order for successful execution.

**This Owner User needs to be the User Name, as presented in the Client Console, that the LogRhythm.Tools API key is associated with.**

```
$LogRhythmListOwner = "LogRhythm Administrator"
```

## Examples 
AD Groups are configured for Synchronization based on establishing a PSCustomObject that contains four key properties.

|Field|Definition|
|--------------|-------|
|Name|This name is to help facilitate tracking and management when reviewing the Script Activity log.|
|InputGroup|This should be set to the name of the Active Directory Group you wish to Sync with LogRhythm Lists|
|Output_IdentityListName|This should be set to the name of the existing and/or new LogRhythm List name value that will contain TrueIdentity values.  Set to $null when not required.|
|Output_LoginListName|This should be set to the name of the existing and/or new LogRhythm list name value that will contain SamAccountName login values.  Set to $null when not required.|


The second component to defining a new AD Group for synchronization is to add the record created to the SyncList variable.  This is accomplished by:
```
$SyncList.Add() 
```

The Variable Name that contains the definitions containing Name, InputGroup, Output_IdentityListName, and Output_LoginListName is the value that must be included inside the .Add().
```
$SyncList.Add($MyADGroupObject)
```

### Example 1 - Synchronization Group Configuration
First define the AD Group for synchronization:
```
$ADGSync1 = [PSCustomObject]@{
    # Name is showcased in the audit log outlining what is being processed.  This name is to help facilitate tracking and management. 
    Name = "Friends of TAM"
	
    # The InputGroup should be the GroupName as it appears in Active Directory and is the source of the Users that will be populated in LogRhyhtm.
    InputGroup = "SG_FOT"
	
    # The Output Identity is the output list name that will be created and maintained in LogRhythm with TrueIdentity values for the input group
    Output_IdentityListName = "LogRhythm - Friends of TAM - Identity"
	
    # The Output Login is the output list name that will be created and maintained in LogRhythm with Login values for the input group
    Output_LoginListName = "LogRhythm - Friends of TAM - Login"
}
```

Second add the defined group established to the SyncList array:
```
$SyncList.add($ADGSync1)
```

### Example 2 - CloudAI Monitored Identities
Here is a more condensed example that showcases synchronizing the members of an AD Group to the existing LogRhythm List for CloudAI membership management.
```
$ADGSync2 = [PSCustomObject]@{
    Name = "LogRhythm CloudAI Subscribed Users"
    InputGroup = "SG_LR_MonitoredIdentities"
    # The Output Identity is the output list name that will be created and maintained in LogRhythm with TrueIdentity values for the input group
    Output_IdentityListName = "CloudAI: Monitored Identities"
    # An Output_* groups can be set to $null.  When the name is set to $null the list will not be created or updated
    Output_LoginListName = $null
}
$SyncList.add($ADGSync2)
```

### Multiple Groups to LogRhythm Lists
The Example for Synchronization Group Configuration can be copied as many times as necissary to facilitate synchronization of multiple groups.
Reference:
```
# Group 1
$ADGSync1 = [PSCustomObject]@{
	~ Content Cut for Example
}
$SyncList.add($ADGSync1)

# Group 2
$ADGSync2 = [PSCustomObject]@{
	~ Content Cut for Example
}
$SyncList.add($ADGSync2)

$ADGSync3 = [PSCustomObject]@{
	~ Content Cut for Example
}
$SyncList.add($ADGSync3)
```

## Sample Output
Below is a sample output that is provided when executed.  This sample output would be the primary contents contained within the output translog.
```
[04/22/21 11:05:20] - Start - List Synchronization
[04/22/21 11:05:20] - Start - Processing List: Technical Account Managers
[04/22/21 11:05:20] - Info - Source AD Group: TAM
[04/22/21 11:05:20] - Info - Destination Identity List: LogRhythm - TAM - Identity
[04/22/21 11:05:20] - Info - Destination Login List: LogRhythm - TAM - Login
[04/22/21 11:05:20] - Info - UserLogin Sync - Adding SamAccountName: sue
[04/22/21 11:05:20] - Info - TrueIdentity Sync - Adding TrueIdentity ID: 99
[04/22/21 11:05:20] - Info - UserLogin Sync - Adding SamAccountName: bob
[04/22/21 11:05:20] - Info - TrueIdentity Sync - Adding TrueIdentity ID: 101
[04/22/21 11:05:20] - Info - UserLogin Sync - Adding SamAccountName: chuck
[04/22/21 11:05:20] - Info - TrueIdentity Sync - Adding TrueIdentity ID: 103
[04/22/21 11:05:20] - Info - UserLogin Sync - Adding SamAccountName: eric
[04/22/21 11:05:20] - Info - TrueIdentity Sync - Adding TrueIdentity ID: 105
[04/22/21 11:05:20] - Info - UserLogin Sync - Adding SamAccountName: rob
[04/22/21 11:05:20] - Info - TrueIdentity Sync - Adding TrueIdentity ID: 107
[04/22/21 11:05:20] - Info - UserLogin Sync - Adding SamAccountName: kelly
[04/22/21 11:05:20] - Info - TrueIdentity Sync - Adding TrueIdentity ID: 109
[04/22/21 11:05:20] - Info - AD Group Member Count: 6
[04/22/21 11:05:20] - Info - SamAccountName Count: 6
[04/22/21 11:05:20] - Info - Destination Login List: LogRhythm - TAM - Login
[04/22/21 11:05:20] - Begin - Synchronizing LogRhythm List: LogRhythm - TAM - Login
[04/22/21 11:05:21] - End - Synchronizing LogRhythm List: LogRhythm - TAM - Login Value Count: 6
[04/22/21 11:05:21] - Info - Identities Count: 6
[04/22/21 11:05:21] - Info - Destination Identity List: LogRhythm - TAM - Identity
[04/22/21 11:05:21] - Begin - Synchronizing LogRhythm List: LogRhythm - TAM - Identity
[04/22/21 11:05:21] - End - Synchronizing LogRhythm List: LogRhythm - TAM - Identity Value Count: 6
[04/22/21 11:05:21] - End - Processing List: Technical Account Managers
[04/22/21 11:05:21] - Start - Processing List: Friends of TAM
[04/22/21 11:05:21] - Info - Source AD Group: SG_FOT
[04/22/21 11:05:21] - Info - Destination Identity List: LogRhythm - Friends of TAM - Identity
[04/22/21 11:05:21] - Info - Destination Login List: LogRhythm - Friends of TAM - Login
[04/22/21 11:05:21] - Info - UserLogin Sync - Adding SamAccountName: berry
[04/22/21 11:05:21] - Info - TrueIdentity Sync - Adding TrueIdentity ID: 112
[04/22/21 11:05:21] - Info - UserLogin Sync - Adding SamAccountName: mill
[04/22/21 11:05:21] - Info - TrueIdentity Sync - Adding TrueIdentity ID: 114
[04/22/21 11:05:21] - Info - AD Group Member Count: 2
[04/22/21 11:05:21] - Info - SamAccountName Count: 2
[04/22/21 11:05:21] - Info - Destination Login List: LogRhythm - Friends of TAM - Login
[04/22/21 11:05:21] - Begin - Synchronizing LogRhythm List: LogRhythm - Friends of TAM - Login
[04/22/21 11:05:21] - End - Synchronizing LogRhythm List: LogRhythm - Friends of TAM - Login Value Count: 2
[04/22/21 11:05:21] - Info - Identities Count: 2
[04/22/21 11:05:21] - Info - Destination Identity List: LogRhythm - Friends of TAM - Identity
[04/22/21 11:05:21] - Begin - Synchronizing LogRhythm List: LogRhythm - Friends of TAM - Identity
[04/22/21 11:05:21] - End - Synchronizing LogRhythm List: LogRhythm - Friends of TAM - Identity Value Count: 2
[04/22/21 11:05:21] - End - Processing List: Friends of TAM
[04/22/21 11:05:21] - Start - Processing List: LogRhythm CloudAI Subscribed Users
[04/22/21 11:05:21] - Info - Source AD Group: SG_LR_MonitoredIdentities
[04/22/21 11:05:21] - Info - Destination Identity List: CloudAI: Monitored Identities
[04/22/21 11:05:21] - Info - Destination Login List: 
[04/22/21 11:05:21] - Info - UserLogin Sync - Adding SamAccountName: sue
[04/22/21 11:05:21] - Info - TrueIdentity Sync - Adding TrueIdentity ID: 99
[04/22/21 11:05:21] - Info - UserLogin Sync - Adding SamAccountName: bob
[04/22/21 11:05:21] - Info - TrueIdentity Sync - Adding TrueIdentity ID: 101
[04/22/21 11:05:21] - Info - UserLogin Sync - Adding SamAccountName: chuck
[04/22/21 11:05:21] - Info - TrueIdentity Sync - Adding TrueIdentity ID: 103
[04/22/21 11:05:21] - Info - UserLogin Sync - Adding SamAccountName: eric
[04/22/21 11:05:21] - Info - TrueIdentity Sync - Adding TrueIdentity ID: 105
[04/22/21 11:05:21] - Info - UserLogin Sync - Adding SamAccountName: rob
[04/22/21 11:05:21] - Info - TrueIdentity Sync - Adding TrueIdentity ID: 107
[04/22/21 11:05:21] - Info - UserLogin Sync - Adding SamAccountName: kelly
[04/22/21 11:05:21] - Info - TrueIdentity Sync - Adding TrueIdentity ID: 109
[04/22/21 11:05:21] - Info - UserLogin Sync - Adding SamAccountName: berry
[04/22/21 11:05:21] - Info - TrueIdentity Sync - Adding TrueIdentity ID: 112
[04/22/21 11:05:21] - Info - UserLogin Sync - Adding SamAccountName: mill
[04/22/21 11:05:22] - Info - TrueIdentity Sync - Adding TrueIdentity ID: 114
[04/22/21 11:05:22] - Info - AD Group Member Count: 8
[04/22/21 11:05:22] - Info - SamAccountName Count: 8
[04/22/21 11:05:22] - Info - Identities Count: 8
[04/22/21 11:05:22] - Info - Destination Identity List: CloudAI: Monitored Identities
[04/22/21 11:05:22] - Begin - Synchronizing LogRhythm List: CloudAI: Monitored Identities
[04/22/21 11:05:22] - End - Synchronizing LogRhythm List: CloudAI: Monitored Identities Value Count: 8
[04/22/21 11:05:22] - End - Processing List: LogRhythm CloudAI Subscribed Users
[04/22/21 11:05:22] - End - List Synchronization
```

## Example PowerShell Notes
This example includes a variety of general best practices.

|Error Handling|Logging|Transcript|OutputReport|
|--------------|-------|----------|------------|
|Light|True|True|False|

### Error Handling
The script itself does not contain any key error handling logic.  The LogRhythm.Tools cmdlets applied in this script do provide Error Output for actions attempted that were not successful.

### Logging
The script is setup to write to output for the record it is currently processing, the status of the processing, and output any identified errors while executing.

### Transcript
The script is setup by default to output a transcript log of the PowerShell execution.

### OutputReport
The script is setup to produce a .csv report the allow review of the automation's execution status for each given row.  

The output csv report is designed to be able to be leveraged as an input.  Note you should correct any underlying merger issues before attempting to re-run an output report back through the merger process.