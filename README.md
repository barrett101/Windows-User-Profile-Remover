# Windows-User-Profile-Remover
PowerShell script that will remove user profiles based on age

**DESCRIPTION**

This script will delete user profiles based on age. This works using a scheduled task that writes a date to a file in the user profile.  The scheduled task will run at logon of any user, and runs every 60 minutes while they are logged in.  Please see "How it Works" section that explains how profile age and cleanup occurs.  Tested on Windows 10 21H2.

**THINGS YOU NEED TO DO TO MAKE THE SCRIPT WORK**

If you need to make exclusions to user accounts search "ACCOUNT EXCLUSIONS HERE" in the RemoveUserProfiles.ps1 to bring you to the IF statement you will need to modify.
You will need to create the working folder location (ex. c:\ProfileRemover) and put the below files in it, and then define the working folder when running the script.  You will also need to adjust the WriteLastLogonDate.vbs file and hard code the path to the PS1 file it references.  The RemoveUserProfiles.ps1 must run as an administrator or system account.

WriteLastLogonDate.vbs

WriteLastLogonDate.ps1

RemoveUserProfiles.ps1

**EXAMPLE**

Below will remove profiles that are older than 8 days
RemoveUserProfiles.ps1 -DeleteProfileOlderInDays 8 -WorkingFolder C:\temp
	
**EXAMPLE**

Below will remove profiles that are older than 0 days, which will delete all profiles on the computer unless they are on exclusion list.
RemoveUserProfiles.ps1 -DeleteProfileOlderInDays 0 -WorkingFolder C:\temp
	
**BACKGROUND OF WHY THIS WAS CREATED**

In the past we have used Delprof2.exe which is a common 3rd party utility for removing user profiles.  In the last year 2020/2021 or so something changed and it seems now the ntuser.dat which resides in the C:\Users\username folder is being written to when a Cumulative Update is run, whether the user has logged in or not.
This causes issues as many of the local functions to get the last logon date are based off this file.  This causes the Group Policy setting that can cleanup old profiles, The WMI Win32_UserProfile class, as well as with Delprof2.exe to not cleanup old profiles properly.  Also the last modified date of the c:\Users\username folder isn't always accurate with the last logon of the user, so it can't be used either. Another note is the Win32_networkloginprofile WMI class pulls from AD, and will not work if not domain connected, and just retrieve the last logon on the domain not the computer.  At first it was determined that the only file the worked was "C:\Users\username\AppData\Local\IconCache.db" at it closely reflected the logon time, but as later found not all user profiles had the file, only some did.  

**HOW IT WORKS**

It will create a scheduled task that will run at logon, and at 60 minute intervals that will write a date to the LastLogonDate.txt file located in the user profile ex. C:\users\username\LastLogonDate.txt.  Using a scheduled task ensure that users that are logged in that may not restart/logoff in weeks have the date updated continuously so they don't accidently get removed.  The script will perform checks to ensure the scheduled task, and necessary files are present for writing the LastLogonDate.txt file.  

It will them generate a list of all user profiles before cleanup.  Next it will go through each of the user accounts in the Win32_UserProfile class, except for special accounts (SYSTEM, NetworkService, and LocalService accounts), it will also avoid service profiles (ex. SQL) that have a local path of C:\Windows\ServiceProfiles.  It will also avoid user accounts missing a local path (a local path being ex. c:\users\jsmith), if this is missing it assumes something is wrong and/or corrupt, another query is run checking for empty local paths and will record the SID for you to investigate.

For each user profile it will create the file LastLogonDate.txt and populate it with today's date.  This only happens if the user profile folder exists, and the LastLogonDate.txt DOES NOT exist.  This creates a starting point for all accounts on the machine to determine how old they are.  This means if you try and delete profiles older than 15 days, you will need to wait 15 days after the initial launch of this script for them to delete.
Next it will check if the LastLogonDate.txt file exist and continue if so.  It will check the last logon date retrieved from the contents of the LastLogonDate.txt file, if the account is older than the specified amount of days it will continue. It will then check if the username is excluded, if not it will continue and attempt to delete the user profile from the machine.  Please note if the user profile is in use it will not process, you will see an error in the log and this is normal.

Log file can be found in the working folder called RemoveUserProfiles.log
