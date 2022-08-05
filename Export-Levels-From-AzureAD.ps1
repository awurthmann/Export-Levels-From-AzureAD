#powershell.exe


# Written by: Aaron Wurthmann
#
# You the executor, runner, user accept all liability.
# This code comes with ABSOLUTELY NO WARRANTY.
# You may redistribute copies of the code under the terms of the GPL v3.
#
# --------------------------------------------------------------------------------------------
# Name: Export-Levels-From-AzureAD.ps1
# Version: 2022.07.08.1733
# Description: This is the AzureAD version of my Export-Levels-from-Outlook, Export-Levels-from-AD and Export-Levels-from-Workday scripts
#				The purpose of these scripts are to export all accounts and show their relation, or levels, from the CEO
#				Privileged access is NOT needed to run any of the Export-Levels scripts, any user can run them and export all users,
#				 Export-Levels-from-Outlook uses Outlook API calls, ..from-AD uses the admin tool kit and ..from-AzureAD uses the AzureAd module 
# 
# Instructions:
#	Running from a PowerShell prompt: Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
# 		.\Export-Levels-From-AzureAD.ps1 -UserPrincipalName <CEO's UserPrincipalName>
#	OR
#	Running from a Run or cmd.exe prompt: 
#		powershell -ExecutionPolicy Bypass -File ".\Export-Levels-From-AzureAD.ps1" <CEO's UserPrincipalName>
#	
# Tested with: Microsoft Windows [Version 10.0.22000.0], PowerShell [5.1.22000.653]
#	"Microsoft Windows [Version $([System.Environment]::OSVersion.Version)], PowerShell [$($PSVersionTable.PSVersion.ToString())]"
#
# Arguments:
#	-UserPrincipalName		Mandatory string value of target's UserPrincipalName
#	-ExportPath 			Optional string value for path to export CSV file, default uses local directory
#	-InfoLog				True/False, Write to information log, default is true
#	-MaxLevel				Maximum number of levels to iterate through, default 10
#	-MaxCount				Maximum number of accounts to check for managers, default is 50,000
#	-Disconnect				True/False, disconnect from Azure Cloud at completion of script, default is true
#	
#
# Example:
#	.\Export-Levels-From-AzureAD.ps1 -UserPrincipalName ceos_upn@company.ext
#
# Output: 
#	CSV file, summary count to standard out, error and info files
#
# WARNING:
#	This script pulls nearly the entirety of your organization's user accounts into memory
#	 I recommend rebooting or at the very least quitting PowerShell afterward
#
# Notes:
#	 Using the CEO's UserPrincipalName is not required, any UserPrincipalName will work and will be set to level 0
# 
# -------------------------------------------------------------------------------------------- 

Param (
	[Parameter(Mandatory=$true)][string]$UserPrincipalName,
	[string]$ExportPath,
	[bool]$InfoLog=$True,
	[int]$MaxLevel=10,
	[int]$MaxCount=50000,
	[bool]$Disconnect=$True
)


###Functions
##Windows Check Function##
function isWindows {
	return $Env:OS -like "Windows*"
} 
##End Windows Check Function##

##Check if Admin Function##
function isAdmin {
#	Checks if the current user has "Administrator" privileges, returns True or False 
	If(isWindows) {
		$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
		return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
	}
	ElseIf ($IsMacOS) {
		If (groups $(users) -contains "admin") {
			return $True
		}
		Else {
			return $False
		}
	}
}
##End Check if Admin Function##

##Write-Log Function
function Write-Log {
	#Missing a file like method, may be prone to I/O errors during heavy writes.
	Param ([string]$LogPath,[string]$LogMessage)

	[string]$LineValue = "PS (C) ["+(Get-Date -Format HH:mm:ss:fff)+"]: $LogMessage"
	#Add-Content -Path $LogPath -Value $LineValue
	$LineValue >> $LogPath
}
##End Write-Log Function

##Write Color Function
function Write-Color {
<#
 
.SYNOPSIS
Reformats Write-Host output, allowing multiple colors on the same line.
 
.DESCRIPTION
Usually to output information in PowerShell we use Write-Host. By using parameter -ForegroundColor you can define nice looking output text. Write-Color takes things a step further, allowing for multiple colors on the same command.


.PARAMETER Text
Text to be used. Encolse with double quotes " " and seperate with comma ,

.PARAMETER Color
Color to use. Seperate with comma ,

.PARAMETER StartTab
Indent text wih a number of tabs.

.PARAMETER LinesBefore
Blank lines to insert before text.

.PARAMETER LinesAfter
Blank lines to insert after text.

.EXAMPLE
Write-Color -Text "Red ", "Green ", "Yellow " -Color Red,Green,Yellow

.EXAMPLE
Write-Color -Text "This is text in Green ",
	"followed by red ",
	"and then we have Magenta... ",
	"isn't it fun? ",
	"Here goes DarkCyan" -Color Green,Red,Magenta,White,DarkCyan

.NOTES
Orginal Author:  Przemys??aw K??ys
 Version 0.2
  - Added Logging to file
 Version 0.1
  - First Draft

Edited by: Aaron Wurthmann
 Versoin 0.2A
  - Removed logging to file ability. Conflicts with our preferred method.
  - Added If statment to encapsulate main body.
  - Removed initialization of StartTab, LinesBefore, LinesAfter and adjusted If statments to reflect change.
    + That's meerly a coding prefference, nothing wrong with Przemys??aw's way.
Edited and tested on PowerShell [Version 5.1.16299.251], Windows [Version 10.0.16299.309]

You can find the colors you can use by using simple code:
	[enum]::GetValues([System.ConsoleColor]) | Foreach-Object {Write-Host $_ -ForegroundColor $_ }

.LINK
Orginal Author's Site -  https://evotec.xyz/powershell-how-to-format-powershell-write-host-with-multiple-colors
#>

Param ([String[]]$Text, [ConsoleColor[]]$Color = "White", [int]$StartTab, [int]$LinesBefore, [int]$LinesAfter=1)

If ($Text) {
		$DefaultColor = $Color[0]
		if ($LinesBefore) {  for ($i = 0; $i -lt $LinesBefore; $i++) { Write-Host "`n" -NoNewline } } # Add empty line before
		if ($StartTab) {  for ($i = 0; $i -lt $StartTab; $i++) { Write-Host "`t" -NoNewLine } }  # Add TABS before text
		if ($Color.Count -ge $Text.Count) {
			for ($i = 0; $i -lt $Text.Length; $i++) { Write-Host $Text[$i] -ForegroundColor $Color[$i] -NoNewLine } 
		} else {
			for ($i = 0; $i -lt $Color.Length ; $i++) { Write-Host $Text[$i] -ForegroundColor $Color[$i] -NoNewLine }
			for ($i = $Color.Length; $i -lt $Text.Length; $i++) { Write-Host $Text[$i] -ForegroundColor $DefaultColor -NoNewLine }
		}
		#Write-Host
		if ($LinesAfter) {  for ($i = 0; $i -lt $LinesAfter; $i++) { Write-Host "`n" } }  # Add empty line after
	}
}
##End Write Color Function

##Install Modules
$Modules=Get-Module -ListAvailable
$RequiredModules=@("AzureAD")
$InstallModules=@()

ForEach ($RequiredModule in $RequiredModules){
	If ($Modules.Name -notcontains $RequiredModule) {
		$InstallModules += $RequiredModule
	}
}
If (($InstallModules).Count -gt 0) {
	$Expression="Install-Module " + $($InstallModules -join ',')
	
	If (isAdmin) {
		Invoke-Expression $Expression
	}
	Else {
		If (isWindows) {
			Start-Process powershell -Verb runAs -ArgumentList $Expression
		}
		ElseIf ($IsMacOS) {
			Invoke-Expression $Expression
		}
	}
}
Clear-Variable Modules,RequiredModules,InstallModules
##End Install Modules

###Environment Setup
##Script Name and Path
$ScriptPath=Split-Path $($MyInvocation.MyCommand.Path) -Parent
$ScriptName=$MyInvocation.MyCommand.Name
##End Script Name and Path

##Export File Settings
If(!($ExportPath)){
	$ExportPath=".\$($(Get-Date).ToUniversalTime().ToString("yyyyMMddHHmm"))_$($ScriptName)" -replace "ps1","csv"
}
#Clear-Variable ScriptPath,ScriptName
##End Export File Settings

##Log File Settings
$ErrorLogFile = '{0}.log' -f $ExportPath -replace "csv","error"
$InfoLogFile = '{0}.log' -f $ExportPath -replace "csv","info"
##End Log File Settings

##Use Pop-Up Browser for Azure AD
If (!($AzAdConnection)){
	$global:AzAdConnection=Connect-AzureAD
}
##End Use Pop-Up Browser for Azure AD

##Operating System Check
If ($IsMacOS) {
	Write-Host
	Write-Warning "This version of $ScriptName has not been fully tested on macOS `n         For best results use Windows 10 or higher"
	Write-Host
}
##End Operating System Check
###End Environment Setup

##Main
If (!($AzAdConnection)){
	$ErrorText="ERROR: Unable to connect to AzureCloud"
	If ($InfoLog) {Write-Log $InfoLogFile $ErrorText}
	Write-Log $ErrorLogFile $ErrorText
	Write-Error -Message "`n$ErrorText" -Category ConnectionError
	exit
}

$Started=Get-Date

If ($InfoLog) {
	Write-Log $InfoLogFile "Connect to $($AzAdConnection.Environment.Name)"
	Write-Log $InfoLogFile "TenantId: $($AzAdConnection.Tenant.Id.Guid)"
	Write-Log $InfoLogFile "TenantDomain: $($AzAdConnection.Tenant.Domain)"
	Write-Log $InfoLogFile "Account: $($AzAdConnection.Account.Id)"
	Write-Log $InfoLogFile "AccountType: $($AzAdConnection.Account.Type)"
	Write-Log $InfoLogFile "Running: Get-AzureADUser -All $True -Filter AccountEnabled eq true"
}

If (!($EnabledUsers)){
	Write-Progress -Activity "Retrieving Enabled Accounts in AzureAD" -status "Running: Get-AzureADUser -All $True -Filter AccountEnabled eq true"
	Get-AzureAdUser -All $True -Filter "AccountEnabled eq true" | 
	 ForEach { $licensed=$False ; For ($i=0; $i -le ($_.AssignedLicenses | 
	 Measure).Count ; $i++) { If( [string]::IsNullOrEmpty(  $_.AssignedLicenses[$i].SkuId ) -ne $True) { $licensed=$true } } ; If( $licensed -eq $true) { [array]$EnabledUsers+=$_ | 
	 Select-Object *,@{label="ManagerUPN";expression={(Get-AzureADUserManager -ObjectId $_.ObjectID).UserPrincipalName}} | Select-Object -Property DisplayName,GivenName,Surname,UserPrincipalName,MailNickName,Mail,CompanyName,JobTitle,Department,ManagerUPN} }
	#
	#$EnabledUsers=Get-AzureADUser -All $True -Filter "AccountEnabled eq true" | Select-Object *,@{label="ManagerUPN";expression={(Get-AzureADUserManager -ObjectId $_.ObjectID).UserPrincipalName}} | Select-Object -Property DisplayName,GivenName,Surname,UserPrincipalName,MailNickName,Mail,CompanyName,JobTitle,Department,ManagerUPN
}

If (($EnabledUsers).Count -gt 1) {
	$TotalCount=$EnabledUsers.count

	If ($InfoLog) {
		Write-Log $InfoLogFile "Completed: Get-AzureADUser -All $True -Filter AccountEnabled eq true"
		Write-Log $InfoLogFile "Total Enabled User Accounts: $TotalCount"
	}
	
	$LastCount = 0
	$Level0UPN=$UserPrincipalName
	Clear-Variable UserPrincipalName
	
	#Level 0 Pass
	$Level=0
	[array]$Users=$EnabledUsers | Where UserPrincipalName -eq $Level0UPN | Select-Object *,@{Name="Level"; Expression={$Level}}
	
	If (!($Users)){
		$ErrorText="ERROR: Unable to find UserPrincipalName $Level0UPN"
		If ($InfoLog) {Write-Log $InfoLogFile $ErrorText}
		Write-Log $ErrorLogFile $ErrorText
		Write-Error -Message "`n$ErrorText" -Category InvalidResult
		exit
	}
	If ($InfoLog) {Write-Log $InfoLogFile "Level $Level = Display Name: $(($Users).DisplayName), UserPrincipalName: $(($Users.UserPrincipalName)), JobTitle: $(($Users.JobTitle))"}	
	
	[array]$NextUPNs=$Users.UserPrincipalName
	#End Level 0 Pass

	#Level 1 Pass
	$Level++
	ForEach ($UPN in $NextUPNs) {
		[int]$SearchLevel=$Level-1
		If ($InfoLog) {Write-Log $InfoLogFile "Checking Level $SearchLevel - UserPrincipalName: $UPN"}
		Write-Progress -Activity "Gathering information on Level $SearchLevel" -status "Checking UserPrincipalName: $UPN" -percentComplete ($LastCount / $TotalCount*100)
		
		$Users += $EnabledUsers | Where {($_.ManagerUPN -eq $UPN) -and ($_.UserPrincipalName -ne $UPN)} | Select-Object *,@{Name="Level"; Expression={$Level}}
		[array]$CheckedUPNs = $UPN
	}
	Clear-Variable NextUPNs
	[array]$NextUPNs = $Users.UserPrincipalName | Where {($CheckedUPNs -notcontains $_)}
	#End Level 1 Pass

	#Level 2+ Passes
	Do {
		$Level++
		$LastCount = $Users.Count

		ForEach ($UPN in $NextUPNs) {
			[int]$SearchLevel=$Level-1
			If ($InfoLog) {Write-Log $InfoLogFile "Checking Level $SearchLevel - UserPrincipalName: $UPN"}
			Write-Progress -Activity "Gathering information on Level $SearchLevel" -status "Checking UserPrincipalName: $UPN" -percentComplete ($LastCount / $TotalCount*100)
			
			$Users += $EnabledUsers | Where {($_.ManagerUPN -eq $UPN) -and ($_.UserPrincipalName -ne $UPN) -and ($CheckedUPNs -notcontains $_.UserPrincipalName)} | Select-Object *,@{Name="Level"; Expression={$Level}}
			$CheckedUPNs += $UPN
		}
		Clear-Variable NextUPNs
		[array]$NextUPNs = $Users.UserPrincipalName | Where {($CheckedUPNs -notcontains $_)}
		
		If($LastCount -ge $MaxCount){
			$InfoMessage="DO-UNTIL loop stopped. Reason: LastCount, $LastCount, reached Max Count Limit of $MaxCount"
			If ($InfoLog) {Write-Log $InfoLogFile $InfoMessage}
			Write-Warning $InfoMessage
			$Stop=$True
			break
		}
		
		If($Level -ge $MaxLevel){
			$InfoMessage="DO-UNTIL loop stopped. Reason: Level, $Level, reached Max Level Limit of $MaxLevel"
			If ($InfoLog) {Write-Log $InfoLogFile $InfoMessage}
			Write-Warning $InfoMessage
			$Stop=$True
			break
		}
	
		If($LastCount -eq $Users.Count){$Stop=$True}

	} Until ($Stop)
	#End Level 2+ Passes
	
	$Finished=Get-Date
	$Users | Export-CSV -NoTypeInformation -Force $ExportPath
	
	If ($InfoLog) {
		Write-Log $InfoLogFile "Total number of accounts in $($Level0UPN)'s org: $($Users.Count)"
		Write-Log $InfoLogFile "Time Elapsed: $(($Finished-$Started).ToString())"
		Write-Log $InfoLogFile "Exported to $ExportPath"
	}
	
	Write-Host ""
	Write-Color "Total number of accounts in ", "$($Level0UPN)'s ", "org: ", "$($Users.Count)" -Color White,Green,White,Yellow
	Write-Color "Time Elapsed: ",$($Finished-$Started).ToString() -Color White,Blue
	Write-Color "Exported to ",$ExportPath -Color White,Magenta
	
	If ($Disconnect){
		Disconnect-AzureAD
		Remove-Variable -Name "AzAdConnection" -Force -Scope "global"
	}
	
}
Else {
	$ErrorText="ERROR: No enabled users accounts were found"
	If ($InfoLog) {Write-Log $InfoLogFile $ErrorText}
	Write-Log $ErrorLogFile $ErrorText
	Write-Error -Message "`n$ErrorText" -Category InvalidResult
	exit
}
##End Main









