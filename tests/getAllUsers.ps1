$MyDir = Split-Path -Parent $MyInvocation.MyCommand.Path
 
[xml]$Config = Get-Content "$MyDir\Settings.xml"

#Domains to check
$Domains = $Config.Settings.Domains.Domain

$users = New-Object System.Collections.ArrayList

foreach($domain in $Domains)
{ 
    $Conn = $domain.LDAP
    $Paths = $domain.Paths.Path
    $csvUsers = @()

    if($domain.Name -eq 'nam')
    {
        $userFile = $MyDir+"/users.csv"
    
        foreach($Path in $Paths)
        {
            $StartDate = Get-Date
             $FullConn = $Conn + $Path
             $FullConn
            
            $Entry = New-Object System.DirectoryServices.DirectoryEntry("$FullConn")
            $LDAPFilter = "(objectClass=organizationalPerson)"
            $directorySearcher = New-Object System.DirectoryServices.DirectorySearcher($Entry, $LDAPFilter)

            $directorySearcher.PropertiesToLoad.Add("sAMAccountName")
            $directorySearcher.PropertiesToLoad.Add("name")
            $directorySearcher.SizeLimit = 0;
            $directorySearcher.PageSize = 500;
        

            $SearchResults = $directorySearcher.FindAll()


            #$SearchResults.Properties
            $i=0
            $j=0
            foreach($result in $SearchResults)
            {
                
                # $result.Properties["name"]
                # foreach($prop in $result.Properties["name"])
                # {
                #     $prop
                # }
                #$result
                $userId = $result.Properties["samaccountname"]
                $displayname = $result.Properties["name"] 

                $row = New-Object System.Object
                $row | Add-Member -MemberType NoteProperty -Name "userid" -Value $userId.ToLower()
                $row | Add-Member -MemberType NoteProperty -Name "name" -Value "$displayname"
                
                if($j -le 1000)
                {
                    $csvUsers += $row
                    $j+=1
                }
                else
                {
                    $csvUsers | Export-Csv -Path $userFile -Append -Encoding "ASCII" -NoTypeInformation
                    $csvUsers = @()
                    $csvUsers += $row
                    $j=0
                }
                Clear-Item Variable:row

                $i+=1
                $i
            }
            $csvUsers | Export-Csv -Path $userFile -Append -Encoding "ASCII" -NoTypeInformation

            $EndDate = Get-Date
 
            $ElapsedTime = New-TimeSpan -Start $StartDate -End $EndDate
            $ElapsedTime
        }  
    }
}

#Begin Group Definition Section
if($Config.Settings.Files.AttributeData)
{
    $AttributeFile = Import-Csv $Config.Settings.Files.AttributeData
    $boolAttributeData = $true
}

#obtain the server instances from the settings file.
$Servers = $Config.Settings.LDAP.Servers.Server

#for each server, create a directory entry and get the group list
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


function processAttributeFile($attributeFile, $Domains, $users)
{
    foreach($domain in $Domains)
    {
        $Name = $domain.Name
        $StartDate = Get-Date
        $csvAttributes = @()

        $domainUsers = $users | Where-Object {$_[0] -eq $Name}

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
    
        $attrFile = $Config.Settings.Directories.Output+"/"+$domain+"_attributes.csv"
        $csvAttributes | Export-Csv -Path $attrFile -Encoding "ASCII" -NoTypeInformation
    
        $EndDate = Get-Date
    
        $ElapsedTime = New-TimeSpan -Start $StartDate -End $EndDate
        Write-Host "It took" $ElapsedTime "to run through the" $domain "domain."
    }   

}

function processSettingsAttributes($Domains)
{
    #for each domain, import the domain user file and run an ldap query to get the selected attributes
    foreach($domain in $Domains)
    {
        $Name = $domain.Name
        $LDAP = $domain.LDAP
        $Attributes = $domain.Attributes.Attribute

        $Entry = New-Object System.DirectoryServices.DirectoryEntry($LDAP)
        $StartDate = Get-Date

        #import user csv here and get the list of users,
        # for each user find the attribute values for the attributes listed in the settings file.
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
}


if($boolAttributeData)
{
    processAttributeFile($AttributeFile,$Domains, $users)
}
else 
{
        $Attributes = $domain.Attributes.Attribute        
}
