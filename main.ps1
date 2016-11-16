$MyDir = Split-Path -Parent $MyInvocation.MyCommand.Path

[xml]$Config = Get-Content "$MyDir\Settings.xml"


$Server = $Config.Settings.LDAP.Server
$Groups = $Config.Settings.Groups
$Domains = $Config.Settings.Domains
$HRFile = Import-Csv $Config.Settings.Files.HRData

$users = New-Object System.Collections.ArrayList

foreach($group in $Groups.Group)
{
    $Conn = $Server + $Config.Settings.LDAP.Paths.Path[0]
    $Entry = New-Object System.DirectoryServices.DirectoryEntry($Conn)
    # $Entry = New-Object System.DirectoryServices.DirectoryEntry($Conn, 
    #     $Config.Settings.Security.UserId, $Config.Settings.Security.Password, "none")
    
    $LDAPFilter = "(&(objectClass=group)(cn=$group))"
    $directorySearcher = New-Object System.DirectoryServices.DirectorySearcher($Entry, $LDAPFilter)
    $SearchResults = $directorySearcher.FindAll()
    foreach($member in $SearchResults.Properties["member"])
    {
        $udc = $member -split ",DC="
        $udc = $udc[1]

        $uid = $member -split ","
        $uid = $uid[0].SubString(3,$uid[0].length -3)
        $users.Add(@($udc,$uid,$group)) > $null
    }
}

Write-Host $foo.EMP_Name

foreach($domain in $Domains.Domain)
{
    $csvUsers = @()
    $csvAttributes = @()
    foreach($user in $users)
    {
        if($user[0] -eq $domain)
        {
            $row = New-Object System.Object
            $row | Add-Member -MemberType NoteProperty -Name "userid" -Value $user[1].ToLower()
            $row | Add-Member -MemberType NoteProperty -Name "name" -Value $user[1]

            $csvUsers += $row

            $row = New-Object System.Object
            $row | Add-Member -MemberType NoteProperty -Name "userid" -Value $user[1].ToLower()
            $row | Add-Member -MemberType NoteProperty -Name "type" -Value "group"
            $row | Add-Member -MemberType NoteProperty -Name "value" -Value $user[2]

            $csvAttributes += $row

            $userRecord = $HRFile | Where-Object {$_.EMP_SOEID -eq $user[1]}

            $row = New-Object System.Object
            $row | Add-Member -MemberType NoteProperty -Name "userid" -Value $user[1].ToLower()
            $row | Add-Member -MemberType NoteProperty -Name "type" -Value "email"
            $row | Add-Member -MemberType NoteProperty -Name "value" -Value $userRecord.EMP_Email

            $csvAttributes += $row
        }
    }

    $userFile = $Config.Settings.Directories.Output+"/"+$domain+"_users.csv"
    $attrFile = $Config.Settings.Directories.Output+"/"+$domain+"_attributes.csv"

    $csvUsers | Export-Csv -Path $userFile -Encoding "UTF8" -NoTypeInformation

    $csvAttributes | Export-Csv -Path $attrFile -Encoding "UTF8" -NoTypeInformation

}

