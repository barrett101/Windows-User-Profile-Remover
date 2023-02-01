[CmdletBinding()]
param (
	[Parameter(Mandatory = $true)]
	[string]$DeleteProfileOlderInDays,
	[Parameter(Mandatory = $true)]
	[string]$WorkingFolder
)
#This will log the script and how it goes
Start-Transcript -Path "$WorkingFolder\RemoveUserProfiles.log"
#Gets the current date
$TodayDate = Get-Date

#
##
###
#START - CREATE SCHEDULED TASK to record logon time stamps
#Initially just put the script into the C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp folder but if a user didn't logon daily it wouldn't be accurate.  For example user logons, never reboots, and stays logged in for weeks.
$ScheduledTaskCheck = Get-ScheduledTask -TaskName "ANY USER - Write Last Logon Date" -ErrorAction SilentlyContinue
If ($ScheduledTaskCheck -ne $null)
{
	Write-Host "Scheduled Task is present, no need to create."
}
Else
{
	Write-Host "scheduled task is not present, will create"
	#This help me get it to run for any user they may logon 
	#https://www.reddit.com/r/PowerShell/comments/qc469s/create_a_scheduled_task_to_run_as_logged_on_user/
	$TaskName1 = "ANY USER - Write Last Logon Date"
	$Description1 = "This scheduled task will run at logon and continuously every 60 minutes for any logged in user.  It will write todays date to c:\Users\username\LastLogonDate.txt"
	$taskAction1 = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "WriteLastLogonDate.vbs //B //Nologo" -WorkingDirectory "$WorkingFolder"
	$taskTrigger1 = New-ScheduledTaskTrigger -AtLogOn
	$taskTrigger2 = New-ScheduledTaskTrigger -RepetitionDuration (New-TimeSpan -Days (365 * 20)) -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 60) -Once
	$TaskSettings1 = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
	$TaskPrinciple = New-ScheduledTaskPrincipal -GroupId "Users"
	Register-ScheduledTask -TaskName $taskName1 -Action $taskAction1 -Trigger $taskTrigger1, $taskTrigger2 -Description $description1 -Settings $TaskSettings1 -Principal $TaskPrinciple
	
}
#END - CREATE SCHEDULED TASK to record logon time stamps
###
##
#

#Performs Checks to ensure that all the pieces are in place, before allowing the script to run.
$verifyPS1 = Test-Path -Type Leaf "$WorkingFolder\WriteLastLogonDate.ps1"
$verifyVBS = Test-Path -Type Leaf "$WorkingFolder\WriteLastLogonDate.vbs"
$verifyScheduledTask = Get-ScheduledTask -TaskName "ANY USER - Write Last Logon Date" -ErrorAction SilentlyContinue

If (($verifyPS1 -eq $true) -and ($verifyVBS -eq $true) -and ($verifyScheduledTask -ne $null))
{
	Write-Host "The WriteLastLogonDate.vbs, WriteLastLogonDate.ps1, and the Scheduled Tasks all exist."
	
	#START - SECTION FOR LOGGING PURPOSES ONLY
	#This give a list of all accounts after process is run
	Write-Host "---------------------------------------------------"
	Write-Host "LIST OF USERS ACCOUNTS ON COMPUTER (BEFORE CLEANUP)"
	Write-Host "---------------------------------------------------"
	#Below will retrieve all user profile entries on the system minsus the SYSTEM, NetworkService, and LocalService accounts, and those that don't have empty localpath (ex. C:\Users\username)
	$listofProfilesLoggingOnly = Get-CimInstance -Class Win32_UserProfile | Where-Object { ($_.sid -notmatch "S-1-5-18") -and ($_.sid -notmatch "S-1-5-19") -and ($_.sid -notmatch "S-1-5-20") -and ($_.localpath -ne $null) }
	#Retrieves a list of profiles that have a null localpath, this may mean they are corrupt
	$listofNULLProfilesLoggingOnly = Get-CimInstance -Class Win32_UserProfile | Where-Object { ($_.localpath -eq $null) }
	Foreach ($p in $listofProfilesLoggingOnly)
	{
		$usernameLoggingOnly = $($p.localpath).Replace("C:\Users\", "")
		Write-Host $usernameLoggingOnly
	}
	Foreach ($p in $listofNULLProfilesLoggingOnly)
	{
		Write-Host "NULL Profile Path Detected: The SID $($p.sid) doesn't have a profile path defined.  It may be corrupt.  Check C:\Users for usernames not displaying on the list above to identify."
	}
	#END - SECTION FOR LOGGING PURPOSES ONLY
	
	#START - USER PROFILE CHECKING AND REMOVAL
	Write-Host "---------------------------------------------------------------------------------------------------------"
	Write-Host "USER PROFILE CHECKING AND REMOVAL ---  Will remove profiles older than $DeleteProfileOlderInDays days."
	Write-Host "---------------------------------------------------------------------------------------------------------"
	#Below will retrieve all user profile entries in the registry minus SYSTEM, NetworkService, and LocalService, and those that don't have empty localpath (ex. C:\Users\username)
	$ListOfUsersProfiles = Get-CimInstance -Class Win32_UserProfile | Where-Object { ($_.sid -notmatch "S-1-5-18") -and ($_.sid -notmatch "S-1-5-19") -and ($_.sid -notmatch "S-1-5-20") -and ($_.localpath -ne $null) }
	#Goes through each user account
	foreach ($user in $ListOfUsersProfiles)
	{
		$username = $($user.localpath).Replace("C:\Users\", "")
		#
		##
		#START - WRITE THE LastLogonDate.txt FILE IF NOT PRESENT
		<#
		Due to there being no sure way of determine profile age, there is another script that runs for all users at logon that writes a file to the user profile called LastLogonDate.txt 
		The below will make sure any existing profiles on the machine have one generated based off the ntuser.dat file if it is present.  Some service accounts,
		or accounts that never fully logon won't be removed by this script as they will not have a ntuser.dat file.  This is to ensure old stale accounts will eventually be removed once
		the LastLogonDate.txt doesn't get written to again.
		#>
		$testUserProfilepath = Test-Path -Type Container "C:\Users\$username"
		$testUserLogonFile = Test-Path -Type Leaf "C:\Users\$username\LastLogonDate.txt"
		If (($testUserProfilepath -eq $true) -and ($testUserLogonFile -eq $false))
		{
			#Because the user is missing the LastLogonDate.txt file it will generate one with today's date as a starting point.
			#This is only designed to run once per profile, once a LastLogonDate.txt file exists this will never run again.
			"$(Get-Date -uformat "%Y/%m/%d")" | Out-File -FilePath "C:\Users\$username\LastLogonDate.txt" -Encoding ascii
		}
		#END - WRITE THE LastLogonDate.txt FILE IF NOT PRESENT
		##
		#
		#Checks if the file below exists as it is used to determine last used time, if it doesn't exist nothing happens.
		IF ((Test-Path -Type Leaf C:\Users\$username\LastLogonDate.txt) -eq $true)
		{
			#Retrieve the date from the file and convert to date
			$LastLogonDate = Get-Content C:\Users\$username\LastLogonDate.txt | Get-Date
			#checks is the last logon is less than today date minus age variable
			If ($LastLogonDate -lt $($TodayDate.AddDays(-$DeleteProfileOlderInDays)))
			{
				# ---------->>>    ACCOUNT EXCLUSIONS HERE   <<<---------- 
				#Exclusions are listed here, to ensure they are not processed.  YOU CAN ADJUST THE IF STATEMENT AS NEEDED.  There are not case sensitive.  If using a partial username to filter out use the -notlike one.
				#Recommend that you keep "Default" account in this list.
				If ($username -ne "Default")
				{
					Write-Host "USER REMOVED $username :  Last used on $LastLogonDate --- Profile is older than $DeleteProfileOlderInDays days, will be removed."
					Write-Host "USER REMOVED $username :  Win32_UserProfile removal proccess STARTED."
					#Will attempt to delete the User Profile using the Win32_UserProfile method
					Get-CimInstance -Class Win32_UserProfile | Where-Object { $_.SID -eq $user.sid } | Remove-CimInstance
					Write-Host "USER REMOVED $username :  Win32_UserProfile removal proccess FINISHED."
				}
				else
				{
					Write-Host "USER ON EXCLUSION LIST $username :  Profile is older than $DeleteProfileOlderInDays days but is excluded"
				}
			}
			else
			{
				"USER EXCLUDED $username :  Last used on $LastLogonDate ----  Profile has been used in the last $DeleteProfileOlderInDays days."
			}
		}
		$username = $null
		$LastLogonDate = $null
		$testUserProfilepath = $null
		$testUserLogonFile = $null
	}
	#END - PROFILE PARSING AND REMOVAL
	
	
	
	#START - SECTION FOR LOGGING PURPOSES ONLY
	#This give a list of all accounts after process is run
	Write-Host "---------------------------------------------------"
	Write-Host "LIST OF USERS ACCOUNTS ON COMPUTER (AFTER CLEANUP)"
	Write-Host "---------------------------------------------------"
	#Below will retrieve all user profile entries on the system minsus the SYSTEM, NetworkService, and LocalService accounts, and those that don't have empty localpath (ex. C:\Users\username)
	$listofProfilesLoggingOnly = Get-CimInstance -Class Win32_UserProfile | Where-Object { ($_.sid -notmatch "S-1-5-18") -and ($_.sid -notmatch "S-1-5-19") -and ($_.sid -notmatch "S-1-5-20") -and ($_.localpath -ne $null) }
	#Retrieves a list of profiles that have a null localpath, this may mean they are corrupt
	$listofNULLProfilesLoggingOnly = Get-CimInstance -Class Win32_UserProfile | Where-Object { ($_.localpath -eq $null) }
	Foreach ($p in $listofProfilesLoggingOnly)
	{
		$usernameLoggingOnly = $($p.localpath).Replace("C:\Users\", "")
		Write-Host $usernameLoggingOnly
	}
	Foreach ($p in $listofNULLProfilesLoggingOnly)
	{
		Write-Host "NULL Profile Path Detected: The SID $($p.sid) doesn't have a profile path defined.  It may be corrupt.  Check C:\Users for usernames not displaying on the list above to identify."
	}
	#END - SECTION FOR LOGGING PURPOSES ONLY
}
else
{
	Write-Host "One of the WriteLastLogonDate.vbs, WriteLastLogonDate.ps1, and/or the Scheduled Tasks DO NOT exist."
}
Stop-Transcript