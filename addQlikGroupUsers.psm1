function addQlikGroupUsers
{
    param(
        [xml]$Config,
        [System.Collections.ArrayList]$domainUsers,
        [System.Collections.ArrayList]$uniqueUsers,
        [String]$domain,
        [String]$LogFile
    )
   
    Write-Host $domainUsers.Count
    Write-Host $uniqueUsers.Count

    LogWrite $logFile "Starting to create user and attribute files for the odbc connections on domain $domain"
    #take the user arraylist and send to csv files.
    $StartDate = Get-Date
    $csvAttributes = @()
    $csvUsers = @()

    #For the users that are identified from the group list, we are going to make sure there is a user file entry for them.
    $i=0
    foreach($user in $uniqueUsers)
    {
        $userRow = New-Object System.Object
        $userRow | Add-Member -MemberType NoteProperty -Name "userid" -Value $user[1].ToLower()
        $userRow | Add-Member -MemberType NoteProperty -Name "name" -Value $user[1]

        $csvUsers += $userRow
        Clear-Item Variable:userRow
        $i+=1
    }

    #Export the user file
    $userFile = $Config.Settings.Directories.Output+"/$domain" + "_users.csv"
    $uniqueUserFile = $Config.Settings.Directories.Output + "/unique_users.csv"
    $csvUsers | Export-Csv -Path $userFile -Encoding "ASCII" -NoTypeInformation
    $csvUsers | Export-Csv -Path $uniqueUserFile -Encoding "ASCII" -NoTypeInformation

    #add the group information for users to the attributes file
    $j=0
    foreach($user in $domainUsers)
    {
        $row = New-Object System.Object
        $row | Add-Member -MemberType NoteProperty -Name "userid" -Value $user[1].ToLower()
        $row | Add-Member -MemberType NoteProperty -Name "type" -Value "group"
        $row | Add-Member -MemberType NoteProperty -Name "value" -Value $user[2]

        $csvAttributes += $row
        Clear-Item Variable:row
        $j+=1
    }

    $attrFile = $Config.Settings.Directories.Output+"/$domain" + "_attributes.csv"
    $csvAttributes | Export-Csv -Path $attrFile -Encoding "ASCII" -NoTypeInformation

    $EndDate = Get-Date

    $ElapsedTime = New-TimeSpan -Start $StartDate -End $EndDate
    LogWrite $LogFile "It took $ElapsedTime to run through the $($domain) domain."
    Clear-Item Variable:csvAttributes
}

Export-ModuleMember -Function addQlikGroupUsers