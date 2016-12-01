$MyDir = Split-Path -Parent $MyInvocation.MyCommand.Path
 
[xml]$Config = Get-Content "$MyDir\Settings.xml"

#Domains to check
$Domains = $Config.Settings.Domains.Domain

#Check for HRFile existence
$boolAttributeData = $false
if($Config.Settings.Files.AttributeData)
{
    $AttributeFile = Import-Csv $Config.Settings.Files.AttributeData
    $boolAttributeData = $true
}

#obtain the server instances from the settings file.
$Servers = $Config.Settings.LDAP.Servers.Server

#create the user array list 
$users = New-Object System.Collections.ArrayList

#need to figure out how to line this up.
<#basically, 
1. each server needs to load its list of groups
2. each group needs to find its members
3. each member needs to be looked up in its own directory.
4. output to proper domain csv files

There needs to be two server lists.  The first list is the list containing
universal groups.  The second is a list for looking up user info and attributes from there.

#>

foreach($server in $Servers)
{
    $Conn = $server.Name
    foreach($path in $server.Paths.Path)
    {
        $FullConn = $Conn + $path
        if($server.Security)
        {
            $Entry = New-Object System.DirectoryServices.DirectoryEntry($FullConn, 
                $server.Security.UserId, $server.Security.Password, "none")            
        }
        else
        {
            $Entry = New-Object System.DirectoryServices.DirectoryEntry($FullConn)            
        }

        #Construct GroupList
        foreach($group in $server.Groups.Group)
        {
            if($group.type -eq "file")
            {
                $GroupList = Import-Csv $group.'#text' -Header "Groups"
                $GroupList = $Groups.Groups
            }
            else
            {
                $GroupList += $group.'#text'    
            }
        }
    }

    #Process Groups and add users that are members of provided universal groups
    #to user arraylist
    $i=0
    foreach($GroupMember in $GroupList)
    {
        $LDAPFilter = "(&(objectClass=group)(cn=$GroupMember))"
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
                $users.Add(@($udc,$uid,$group,$member)) > $null
            }
        }    
        $i+=1
        Write-Progress -Activity "Processed Group: $GroupMember" -status "Processed $i Groups" -percentComplete ($i/$Groups.Count*100)            
    }
}

foreach($domain in $Domains)
{
    $Name = $domain.Name
    $LDAP = $domain.LDAP
    $Attributes = $domain.Attributes.Attribute

    $Entry = New-Object System.DirectoryServices.DirectoryEntry($LDAP)

    $StartDate = Get-Date
    $csvUsers = @()
    $csvAttributes = @()

    $domainUsers = $users | Where-Object {$_[0] -eq $Name}
    $uniqueUsers = $domainUsers | Sort-Object @{Expression={$_[1]}; Ascending=$false} -Unique

    $i=0
    foreach($user in $uniqueUsers)
    {
        $row = New-Object System.Object
        $row | Add-Member -MemberType NoteProperty -Name "userid" -Value $user[1].ToLower()
        $row | Add-Member -MemberType NoteProperty -Name "name" -Value $user[1]
 
        $csvUsers += $row

        $LDAPFilter = "(&(objectClass=person)(cn=$user[3]))"
        $directorySearcher = New-Object System.DirectoryServices.DirectorySearcher($Entry, $LDAPFilter)
        $SearchResults = $directorySearcher.FindAll()

        foreach($attribute in $Attributes)
        {
            if($attribute -eq "memberof")
            {
                $groups = $SearchResults.Properties."$attribute"
                foreach($group in $groups)
                {
                    $groupName = $group -split ","

                    $row = New-Object System.Object
                    $row | Add-Member -MemberType NoteProperty -Name "userid" -Value $user[1].ToLower()
                    $row | Add-Member -MemberType NoteProperty -Name "type" -Value "group"
                    $row | Add-Member -MemberType NoteProperty -Name "value" -Value $groupName[0].SubString(3,$groupName[0].length -3)
             
                    $csvAttributes += $row
                }
            }
            else 
            {
                if($SearchResults.Properties."$attribute" -ne $null)
                {
                    $row = New-Object System.Object
                    $row | Add-Member -MemberType NoteProperty -Name "userid" -Value $user[1].ToLower()
                    $row | Add-Member -MemberType NoteProperty -Name "type" -Value $attribute
                    $row | Add-Member -MemberType NoteProperty -Name "value" -Value $SearchResults.Properties."$attribute"
                    $csvAttributes += $row
                }
            }
        }
        $i+=1
        Write-Progress -Activity "Creating unique rows" -status "Created $i rows" -percentComplete ($i/$uniqueUsers.Count*100)
    }

    $j=0
    foreach($user in $domainUsers)
    {
        #Write-Host $user[1]
        $row = New-Object System.Object
        $row | Add-Member -MemberType NoteProperty -Name "userid" -Value $user[1].ToLower()
        $row | Add-Member -MemberType NoteProperty -Name "type" -Value "group"
        $row | Add-Member -MemberType NoteProperty -Name "value" -Value $user[2]
 
        $csvAttributes += $row
 
        $j+=1
        Write-Progress -Activity "Creating group rows" -status "Created $j rows" -percentComplete ($j/$domainUsers.Count*100)        
    }
 
    $userFile = $Config.Settings.Directories.Output+"/"+$domain+"_users.csv"
    $csvUsers | Export-Csv -Path $userFile -Encoding "ASCII" -NoTypeInformation
 
    $attrFile = $Config.Settings.Directories.Output+"/"+$domain+"_attributes.csv"
    $csvAttributes | Export-Csv -Path $attrFile -Encoding "ASCII" -NoTypeInformation
 
    $EndDate = Get-Date
 
    $ElapsedTime = New-TimeSpan -Start $StartDate -End $EndDate
    Write-Host "It took" $ElapsedTime "to run through the" $domain "domain."

}
 
# foreach($domain in $Domains.Domain)
# {
#     $StartDate = Get-Date
#     $csvUsers = @()
#     $csvAttributes = @()
 
#     $domainUsers = $users | Where-Object {$_[0] -eq $domain}
 
#     $uniqueUsers= $domainUsers | Sort-Object @{Expression={$_[1]}; Ascending=$false} -Unique
#     #Create the user file
#     $i=0
#     foreach($user in $uniqueUsers)
#     {
 
#         $row = New-Object System.Object
#         $row | Add-Member -MemberType NoteProperty -Name "userid" -Value $user[1].ToLower()
#         $row | Add-Member -MemberType NoteProperty -Name "name" -Value $user[1]
 
#         $csvUsers += $row
 
#         $userRecord = $null
#         foreach($line in $HRFile)
#         {
#             if($line.EMP_SOEID -eq $user[1])
#             {
#                 $userRecord = $line
#                 break
#             }
#         }

#         $row = New-Object System.Object
#         $row | Add-Member -MemberType NoteProperty -Name "userid" -Value $user[1].ToLower()
#         $row | Add-Member -MemberType NoteProperty -Name "type" -Value "email"
#         $row | Add-Member -MemberType NoteProperty -Name "value" -Value $userRecord.EMP_Email
 
#         $csvAttributes += $row
 
#         $i+=1
#         Write-Progress -Activity "Creating unique rows" -status "Created $i rows" -percentComplete ($i/$uniqueUsers.Count*100)
 
#     }
 
#     $j=0
#     foreach($user in $domainUsers)
#     {
#         #Write-Host $user[1]
#         $row = New-Object System.Object
#         $row | Add-Member -MemberType NoteProperty -Name "userid" -Value $user[1].ToLower()
#         $row | Add-Member -MemberType NoteProperty -Name "type" -Value "group"
#         $row | Add-Member -MemberType NoteProperty -Name "value" -Value $user[2]
 
#         $csvAttributes += $row
 
#         $j+=1
#         Write-Progress -Activity "Creating group rows" -status "Created $j rows" -percentComplete ($j/$domainUsers.Count*100)        
#     }
 
#     $userFile = $Config.Settings.Directories.Output+"/"+$domain+"_users.csv"
#     $csvUsers | Export-Csv -Path $userFile -Encoding "UTF8" -NoTypeInformation
 
#     $attrFile = $Config.Settings.Directories.Output+"/"+$domain+"_attributes.csv"
#     $csvAttributes | Export-Csv -Path $attrFile -Encoding "UTF8" -NoTypeInformation
 
#     $EndDate = Get-Date
 
#     $ElapsedTime = New-TimeSpan -Start $StartDate -End $EndDate
#     Write-Host "It took" $ElapsedTime "to run through the" $domain "domain."
 
# }
