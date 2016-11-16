$conn = "LDAP://qliktech.com/OU=Activate Groups,DC=qliktech,DC=com"
$entry = New-Object System.DirectoryServices.DirectoryEntry($conn,"qtsel\jog","Pats2015","none")

$ldapFilter = "(&(objectClass=group)(cn=DL-Americas-PreSales))"

$directorySearcher = New-Object System.DirectoryServices.DirectorySearcher($entry, $ldapFilter)

$results= $directorySearcher.FindAll()


foreach($result in $results)
{
    
    foreach($member in $result.Properties["member"])
    {
        $conn2 = "LDAP://qliktech.com/DC=qliktech,DC=com"
        $entry2 = New-Object System.DirectoryServices.DirectoryEntry($conn2,"qtsel\jog","Pats2015","none")
        $memberFilter = "(distinguishedName=$member)"
        $memberSearcher = New-Object System.DirectoryServices.DirectorySearcher($entry2,$memberFilter)
        $myRes = $memberSearcher.FindAll()

        #Write-Host $myRes.Properties["sAMAccountName"]

        $domain = $member -split ",DC=" 

        $uid = $member -split ","

        $uid = $uid[0].SubString(3,$uid[0].length -3)

        $domain = $domain[1]
        Write-Host $domain\$uid

    }
}