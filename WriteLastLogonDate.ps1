#The below checks for the user profile path
$testUserProfilepath = Test-Path -Type Container "C:\Users\$($env:Username)"

#If the path exists then it will write the date to the file
If ($testUserProfilepath -eq $true)
{
	"$(Get-Date -uformat "%Y/%m/%d")" | Out-File -FilePath "C:\Users\$($env:Username)\LastLogonDate.txt" -Encoding ascii
}