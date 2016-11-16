
$userFile = Import-Csv 'f:/my documents/_git/qs-odbc-udc-util/users.csv'

$users = New-Object System.Collections.ArrayList

foreach($user in $userFile)
{
    
   $users.Add(@($user.udc,$user.userid,$user.group)) > $null
}

Write-Host $users.Count

$uniqueUsers = $users | Sort-Object @{Expression={$_[1]}; Ascending=$false} -Unique

Write-Host $uniqueUsers.Count

foreach($user in $uniqueUsers)
{
    Write-Host $user[1]
}