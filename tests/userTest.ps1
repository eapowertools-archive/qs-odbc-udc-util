$MyDir = Split-Path -Parent $MyInvocation.MyCommand.Path
 
[xml]$Config = Get-Content "$MyDir\Settings.xml"


$conn = "LDAP://qliktech.com/CN=Jeffrey Goldberg,OU=Users,OU=USA,DC=qliktech,DC=com"
# $LDAPFilter = "(&(objectClass=group)(cn=$GroupMember))"
#         $directorySearcher = New-Object System.DirectoryServices.DirectorySearcher($Entry, $LDAPFilter)
#         $SearchResults = $directorySearcher.FindAll()


$Entry = New-Object System.DirectoryServices.DirectoryEntry($conn)    
$directorySearcher = New-Object System.DirectoryServices.DirectorySearcher($Entry)
$SearchResults = $directorySearcher.FindAll()


$attributes = "memberof"


foreach($attribute in $attributes)
{
    $groups = $SearchResults.Properties."$attribute"

    foreach($group in $groups)
    {
        $groupName = $group -split ","
        #$groupName[0]

        $groupName[0].SubString(3,$groupName[0].length -3)
    }
}

# foreach($foo in $SearchResults.Properties)
# {
#     $foo."$attribute"
# }

# foreach($foo in $SearchResults.Properties)
# {
#     $foo.mail
# }

# foreach($attribute in $attributes)
# {
#     $attribute
     

# }
