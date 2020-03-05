
<#
.SYNOPSIS
  Get the last logon report of users that have not logged for the past XX (Default 60) days from multiple domain controlers.
.DESCRIPTION
  Get details of users that have not logged on or are inactive for the past 60 days across the domain and get the latest value from multiple domain controllers
.INPUTS
  None. Script captures Forest and Domain details when run in the enviornment. 
.OUTPUTS
  Generated output CSV file will be in the created in the same path from where the script was executed.
.NOTES
  Version:        2.0
  Author:         Mohammed Wasay
  Email:          hello@mowasay.com
  Web:            www.mowasay.com
  Creation Date:  02/14/2020
.EXAMPLE
  Get-LastLogonReport.ps1 
#>

#Get Logged on user details
$cuser = $env:USERDOMAIN + "\" + $env:USERNAME
Write-Host -ForegroundColor Gray "Running script as: $cuser authenticated on $env:LOGONSERVER"

#Get the Forest Domain
$forest = (Get-ADForest).RootDomain

#Get all the Domains in the Forest
$domains = (Get-ADForest).Domains

#Time format for report naming
$timer = (Get-Date -Format MM-dd-yyyy)

Write-Host -ForegroundColor Magenta "Your Forest is: $forest"

#Loop through each domain
foreach ($domain in $domains) {
  Write-Host -ForegroundColor Yellow "Working on Domain: $domain"

  #Get all the domain controllers in the domain
  $dcs = Get-ADDomainController -Filter * -Server $domain

  #Storing all the users in an array for comparison later
  $users = @()

  foreach ($dc in $dcs.Hostname) {
    Write-Host -ForegroundColor Cyan "Working on Domain Controller: $dc"
 
    #Days Inactive - Modify the value to the number of days (1,30,45,60,90,120)
    $DaysInactive = "60"
    $time = (Get-Date).Adddays( - ($DaysInactive))

    #Get all AD Users with lastLogonTimestamp less than our time
    $users += Get-ADUser -Filter { lastlogondate -le $time } -Properties * -Server $dc | `
      Select-Object Enabled, `
    @{Name = "Domain"; Expression = { $domain } }, `
      samAccountName, `
      displayName, `
      lastlogondate, `
      lastlogon, `
    @{Name = 'DC'; Expression = { $dc } }, `
      whenCreated, `
      description, `
      distinguishedName, `
      department, `
      company, `
      office 
  }
  Write-Host -ForegroundColor Yellow "Sorting for most recent lastlogons"
   
  #Get the last logon from each server for every filtered user and used the last entry available
  $LatestLogOn = @()
  $users | Group-Object -Property samAccountName | ForEach-Object { 
          
    $LatestLogOn += ($_.Group | Sort-Object -Property lastlogon -Descending)[0] 
              
    $users.Clear() 
  }
  
  #Export the results to a single file per forest/multidomain
  $LatestLogOn | Select-Object Enabled, `
    Domain, `
    samAccountName, `
    displayName, `
  @{Name = 'lastlogondatetime'; Expression = { [datetime]::FromFileTime($_.lastlogon) -replace '12/31/1600 7:00:00 PM', 'Never' -replace '1/1/1601 12:00:00 AM', 'Never' } }, `
    lastlogon, `
    DC, `
    whenCreated, `
    description, `
    distinguishedName, `
    department, `
    company, `
    office `
  | Sort-Object lastlogondatetime -Descending | Export-Csv ./$forest-InactiveUserReport-$timer.csv -NoTypeInformation -Append

  #Uncomment below if exported results need to be multiple files seperated per domain
  #Export the results to a seperate file per domain
  <#
  $LatestLogOn | Select-Object Enabled, `
    Domain, `
    samAccountName, `
    displayName, `
  @{Name = 'lastlogondatetime'; Expression = { [datetime]::FromFileTime($_.lastlogon) -replace '12/31/1600 7:00:00 PM', 'Never' -replace '1/1/1601 12:00:00 AM', 'Never' } }, `
    lastlogon, `
    DC, `
    whenCreated, `
    description, `
    distinguishedName, `
    department, `
    company, `
    office `
  | Sort-Object lastlogondatetime -Descending | Export-Csv ./$domain-InactiveUserReport-$timer.csv -NoTypeInformation -Append
  #>
    
  Write-Host -ForegroundColor Green "Report for $domain generated!"
}
Write-Host -ForegroundColor Green "------======= Done! =======------"