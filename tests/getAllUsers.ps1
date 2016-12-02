$MyDir = Split-Path -Parent $MyInvocation.MyCommand.Path
 
[xml]$Config = Get-Content "$MyDir\Settings.xml"

#Domains to check
$Domains = $Config.Settings.Domains.Domain


$users = New-Object System.Collections.ArrayList

foreach($domain in $Domains)
{
    $Conn = $domain.LDAP
    $Path = $domain.Path

    if($domain.Name -eq 'qliktech')
    {
         $FullConn = $Conn + $Path
         $FullConn
            
        $Entry = New-Object System.DirectoryServices.DirectoryEntry("$FullConn")
        $LDAPFilter = "(objectClass=organizationalPerson)"
        $directorySearcher = New-Object System.DirectoryServices.DirectorySearcher($Entry, $LDAPFilter)
        
        $directorySearcher.SizeLimit = 0;
        $directorySearcher.PageSize = 500;
        
        $SearchResults = $directorySearcher.FindAll()

        #$SearchResults.Properties

        foreach($result in $SearchResults)
        {
            # $result.Properties["name"]
            # foreach($prop in $result.Properties["name"])
            # {
            #     $prop
            # }

            $userId = $result.Properties["samaccountname"]
            $displayname = $result.Properties["name"] 

            $users.Add(@($userId,$displayname)) > $null
        }
    }
}

$csvUsers = @()

foreach($user in $users)
{
    $userId = $user[0].ToLower()
    $displayname = $user[1] 

    $row = New-Object System.Object
    $row | Add-Member -MemberType NoteProperty -Name "userid" -Value $userId
    $row | Add-Member -MemberType NoteProperty -Name "name" -Value "$displayname"

    $csvUsers += $row

}

$userFile = $MyDir+"/users.csv"
    $csvUsers | Export-Csv -Path $userFile -Encoding "ASCII" -NoTypeInformation
