# Export-Levels-From-AzureAD
This is the AzureAD version of my Export-Levels-from-Outlook, Export-Levels-from-AD and Export-Levels-from-Workday scripts
The purpose of these scripts are to export all accounts and show their relation, or levels, from the CEO
Privileged access is NOT needed to run any of the Export-Levels scripts, any user can run them and export all users,
Export-Levels-from-Outlook uses Outlook API calls, ..from-AD uses the admin tool kit and ..from-AzureAD uses the AzureAD module

## Legal:
You the executor, runner, user accept all liability.
This code comes with ABSOLUTELY NO WARRANTY.
You may redistribute copies of the code under the terms of the GPL v3.

## Warning:
This script pulls nearly the entirety of your organizations user accounts into memory. I recommend rebooting or at the very least quitting PowerShell afterward.

## Instructions:
Running from a PowerShell prompt: Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

	.\Export-Levels-From-AzureAD.ps1 -UserPrincipalName <CEO's UserPrincipalName>
OR

Running from a Run or cmd.exe prompt: 

	powershell -ExecutionPolicy Bypass -File ".\Export-Levels-From-AzureAD.ps1" <CEO's UserPrincipalName>
