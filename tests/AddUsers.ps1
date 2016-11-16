param(
    [Parameter(Mandatory=$true)][string]$userList
)

Import-Csv $userList | New-ADUser -Enabled $true -PasswordNeverExpires $true -ChangePasswordAtLogon $false -AccountPassword (ConvertTo-SecureString R4ndom! -AsPlainText -force) -Company "112adams"