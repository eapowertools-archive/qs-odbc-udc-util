$MyDir = Split-Path -Parent $MyInvocation.MyCommand.Path

[xml]$Config = Get-Content "$MyDir\Settings.xml"


$Server = $Config.Settings.LDAP.Server

$Domains = $Config.Settings.Domains
$HRFile = Import-Csv $Config.Settings.Files.HRData

$users = New-Object System.Collections.ArrayList

if($Config.Settings.Files.Groups)
{
    Write-Host $Config.Settings.Files.Group "Exists"
    $Groups = Import-Csv $Config.Settings.Files.Group -Header "Groups"
    $Groups = $Groups.Groups
}
else
{
    $Groups = $Config.Settings.Groups.Group    
}

$i=0
foreach($group in $Groups)
{
    $Conn = $Server + $Config.Settings.LDAP.Paths.Path[0]
    $Entry = New-Object System.DirectoryServices.DirectoryEntry($Conn)
    # $Entry = New-Object System.DirectoryServices.DirectoryEntry($Conn, 
    #     $Config.Settings.Security.UserId, $Config.Settings.Security.Password, "none")
    
    $LDAPFilter = "(&(objectClass=group)(cn=$group))"
    $directorySearcher = New-Object System.DirectoryServices.DirectorySearcher($Entry, $LDAPFilter)
    $SearchResults = $directorySearcher.FindAll()

    $SearchCount = $SearchResults.Properties["member"].Count

    if($SearchCount -ne 0)
    {
        foreach($member in $SearchResults.Properties["member"])
        {
            $udc = $member -split ",DC="
            $udc = $udc[1]

            $uid = $member -split ","
            $uid = $uid[0].SubString(3,$uid[0].length -3)
            $users.Add(@($udc,$uid,$group)) > $null
        }
    }

    $i+=1
    Write-Progress -Activity "Processed Group:" $group -status "Processed $i Groups" -percentComplete ($i/$Groups.Count*100)
}


foreach($domain in $Domains.Domain)
{
    $csvUsers = @()
    $csvAttributes = @()

    $domainUsers = $users | Where-Object {$_[0] -eq $domain}
    Write-Host "Total entries for " $domain "=" $domainUsers.Count

    $uniqueUsers= $domainUsers | Sort-Object @{Expression={$_[1]}; Ascending=$false} -Unique
    Write-Host "Unique user entries for " $domain "=" $uniqueUsers.Count

    #Create the user file
    $i=0
    foreach($user in $uniqueUsers)
    {
        $row = New-Object System.Object
        $row | Add-Member -MemberType NoteProperty -Name "userid" -Value $user[1].ToLower()
        $row | Add-Member -MemberType NoteProperty -Name "name" -Value $user[1]

        $csvUsers += $row

        $userRecord = $HRFile | Where-Object {$_.EMP_SOEID -eq $user[1]}

        $row = New-Object System.Object
        $row | Add-Member -MemberType NoteProperty -Name "userid" -Value $user[1].ToLower()
        $row | Add-Member -MemberType NoteProperty -Name "type" -Value "email"
        $row | Add-Member -MemberType NoteProperty -Name "value" -Value $userRecord.EMP_Email

        $csvAttributes += $row

        $i+=1
        Write-Progress -Activity "Creating unique rows" -status "Created $i rows" -percentComplete ($i/$uniqueUsers.Count*100)
    }

    $j=0
    foreach($user in $domainUsers)
    {
        $row = New-Object System.Object
        $row | Add-Member -MemberType NoteProperty -Name "userid" -Value $user[1].ToLower()
        $row | Add-Member -MemberType NoteProperty -Name "type" -Value "group"
        $row | Add-Member -MemberType NoteProperty -Name "value" -Value $user[2]

        $csvAttributes += $row

        $j+=1
        Write-Progress -Activity "Creating group rows" -status "Created $j rows" -percentComplete ($j/$domainUsers.Count*100)        
    }

    $userFile = $Config.Settings.Directories.Output+"/"+$domain+"_users.csv"
    $csvUsers | Export-Csv -Path $userFile -Encoding "UTF8" -NoTypeInformation

    $attrFile = $Config.Settings.Directories.Output+"/"+$domain+"_attributes.csv"
    $csvAttributes | Export-Csv -Path $attrFile -Encoding "UTF8" -NoTypeInformation

}

