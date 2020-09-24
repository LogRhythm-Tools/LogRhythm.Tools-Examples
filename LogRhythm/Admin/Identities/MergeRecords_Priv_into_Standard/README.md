# TrueIdentity: Merge Identities Example

# Overview
This example provides the means to merge existing TrueID Records containing Privileged AD Account identifiers into TrueID Records for a given user's TrueIdentity containing their Standard AD Account identifiers.

In this example the Identifier that is listed as the Privileged_SamAccountName provides the lookup into the TrueIdentity record that will be merged into the TrueIdentity Record containing the SamAccountName.  The script has the appropriate logic to prevent attempting to merge identifiers that have previously been merged.


A .csv file is leveraged for this example.  Reference the repo file: Input_TrueID_Merge_PrivID_to_SamAccountID.csv


The Example also supports leveraging the produced output as an input, granting the ability to review the merge results and perform any manual modifications necissary before re-running the merger task.

---------
## Input Object



|NameFirst|NameLast|SamAccountName|Privileged_SamAccountName|
|---------|--------|--------------|-------------------------|
|Ferdinand|Francis|Ferdinand.Francis|adm_ffrancis|
|Donovan|Wheeler|Donovan.Wheeler|adm_dwheeler|
|Darryl|Dawson|Darryl.Dawson|adm_ddawson|
|Rachel|Morrison|Rachel.Morrison|adm_rmorrison|
|September|Huff|September.Huff|adm_shuff|
|Dane|Obrien|Dane.Obrien|adm_dobrien|
|Tiger|Bernard|Tiger.Bernard|adm_tbernard|
|Delly|Obrien|Delly.Obrien|adm_dobrien|
|Kelly|Ritz|Kelly.Ritz|adm_kritz|

## Output Object


|NameFirst|NameLast|SamAccountName|Privileged_SamAccountName|SamAccountTrueID|SamAccountTrueIDStatus|PrivilegedTrueID|PrivilegedTrueIDStatus|MergeStatus|MergeNote|MergeDate|
|---------|--------|--------------|-------------------------|----------------|----------------------|----------------|----------------------|---------|-----------|---------|
|Ferdinand|Francis|Ferdinand.Francis|adm_ffrancis|4806|Active|4806|Active|TRUE|TrueId merge successful.  Merger verified.|[09/23/20 10:53:00]|
|Donovan|Wheeler|Donovan.Wheeler|adm_dwheeler|4595|Active|4595|Active|TRUE|TrueId merge successful.  Merger verified.|[09/23/20 10:53:00]|
|Darryl|Dawson|Darryl.Dawson|adm_ddawson|10571|Active|10571|Active|TRUE|TrueId merge successful.  Merger verified.|[09/23/20 10:53:01]|
|Rachel|Morrison|Rachel.Morrison|adm_rmorrison|21067|Active|21067|Active|TRUE|Identities previously synchronized.  No changes required.|[09/23/20 10:53:02]|
|September|Huff|September.Huff|adm_shuff|14658|Active|14658|Active|TRUE|Identities previously synchronized.  No changes required.|[09/23/20 10:53:02]|
|Dane|Obrien|Dane.Obrien|adm_dobrien|||||FALSE|Duplicate Privileged_SamAccountName's identified.  Privileged_SamAccountName's must be unique.|[09/23/20 10:53:03]|
|Tiger|Bernard|Tiger.Bernard|adm_tbernard|10026|Active|||FALSE|No TrueID record found for the Privileged_SamAccountName|[09/23/20 10:53:03]|
|Delly|Obrien|Delly.Obrien|adm_dobrien|||||FALSE|Duplicate Privileged_SamAccountName's identified.  Privileged_SamAccountName's must be unique.|[09/23/20 10:53:03]|
|Kelly|Ritz|Kelly.Ritz|adm_kritz|||15882|Active|FALSE|No TrueID record found for the SamAccountName|[09/23/20 10:35:38]|



---------

## Example PowerShell Notes
This example includes a variety of general best practices.

|Error Handling|Logging|Transcript|OutputReport|
|--------------|-------|----------|------------|
|Moderate|True|True|True|

### Error Handling
The script will inspect to ensure that each row being processed is unique.  No duplicate SamAccountName or Privileged_SamAccountName values can be present.  

The script will validate if a merger is required by comparing the TrueID values between the two login records (SamAccountName and Privileged_SamAccountName).  If the TrueID record numbers are the same then no merger is required as they are a part of the same TrueID record.

Lastly the script will evaluate for any null response from the TrueIdentity login lookup.  If the LogRhythm TrueIdentity service does not contain a record containing a given login value the script will provide a merger note defining which value was not present in the TrueIdentity dataset.

### Logging
The script is setup to write to output for the record it is currently processing, the status of the processing, and output any identified errors while executing.

### Transcript
The script is setup by default to output a transcript log of the PowerShell execution.

### OutputReport
The script is setup to produce a .csv report the allow review of the automation's execution status for each given row.  

The output csv report is designed to be able to be leveraged as an input.  Note you should correct any underlying merger issues before attempting to re-run an output report back through the merger process.