$MyDir = Split-Path -Parent $MyInvocation.MyCommand.Path
 
[xml]$Config = Get-Content "$MyDir\Settings.xml"

#Domains to check
$Domains = $Config.Settings.Domains.Domain

$users = New-Object System.Collections.ArrayList

$OverallStart = Get-Date

#This section builds the user files for each domain 
foreach($domain in $Domains)
{ 
    $Conn = $domain.LDAP
    $Paths = $domain.Paths.Path
    $csvUsers = @()
    $userFile = $Config.Settings.Directories.Output+"/"+$domain.Name+"_users.csv"
    $csvUsers | Export-Csv -Path $userFile -Encoding "ASCII" -NoTypeInformation
    
    if($domain.Name -eq 'nam')
    {
        $Accounts = $Config.Settings.ServiceAccounts.Account
        foreach($Account in $Accounts)
        {
            $row = New-Object System.Object
            $row | Add-Member -MemberType NoteProperty -Name "userid" -Value $Account.UserId
            $row | Add-Member -MemberType NoteProperty -Name "name" -Value $Account.DisplayName

            $csvUsers += $row
            Clear-Item Variable:row
        }
        
         $csvUsers | Export-Csv -Path $userFile -Append -Encoding "ASCII" -NoTypeInformation
            $csvUsers = @()
    }
    
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

        Write-Host $Path has $SearchResults.Count users to add to the users files
        
        $i=0
        $j=0
        foreach($result in $SearchResults)
        {
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
        }

        $csvUsers | Export-Csv -Path $userFile -Append -Encoding "ASCII" -NoTypeInformation

        $EndDate = Get-Date

        $ElapsedTime = New-TimeSpan -Start $StartDate -End $EndDate
        Write-Host $ElapsedTime
    }   
}
#End User file generation

#Begin Group Definition Section
#for an attribute file that contains additional attributes to add to the attribute file per domain.
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
    $Conn
    foreach($path in $server.Paths.Path)
    {
        $FullConn = $Conn + $path
        $FullConn
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
                $GroupList = $GroupList.Groups
            }
            else
            {
                $GroupList += $group.'#text'    
            }
        }

        #Process Groups and add users that are members of provided universal groups
        #to user arraylist
        $i=0
        foreach($GroupMember in $GroupList)
        {
            $LDAPFilter = "(&(objectClass=group)(cn=$GroupMember))"
            $directorySearcher = New-Object System.DirectoryServices.DirectorySearcher($Entry, $LDAPFilter)
            $directorySearcher.SizeLimit = 0;
            $directorySearcher.PageSize = 500;
            $SearchResults = $directorySearcher.FindAll()
    
            foreach($property in $SearchResults.Properties.PropertyNames)
            {
                #$property
                if($property.StartsWith("member"))
                {
                    if(($SearchResults.Properties[$property].Count -gt 0) -or 
                        ($SearchResults.Properties[$property].Count -ne $null))
                    {
                        $SearchCount = $SearchResults.Properties[$property].Count
                        foreach($member in $SearchResults.Properties[$property])
                        {
                            $udc = $member -split ",DC="
                            $udc = $udc[1]
                            $uid = $member -split ","
                            $uid = $uid[0].SubString(3,$uid[0].length -3)
                            $users.Add(@($udc,$uid,$GroupMember,$member)) > $null
                        }
                    }
                }
            }    
            $i+=1
            Write-Progress -Activity "Processed Group: $GroupMember" -status "Processed $i Groups" -percentComplete ($i/$GroupList.Count*100)            
        }
    }
} 

#take the user arraylist and send to csv files.
foreach($domain in $Domains)
{
    $Name = $domain.Name
    $StartDate = Get-Date
    $csvAttributes = @()
    $csvUsers = @()

    $Name

    $domainUsers = $users | Where-Object {$_[0] -eq $Name}
    $uniqueUsers = $domainUsers | Sort-Object @{Expression={$_[1]}; Ascending=$false} -Unique

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
        Write-Progress -Activity "Creating unique rows" -status "Created $i rows" -percentComplete ($i/$uniqueUsers.Count*100)
    }

    #Export the user file
    $userFile = $Config.Settings.Directories.Output+"/"+$domain.Name+"_users.csv"
    $csvUsers | Export-Csv -Path $userFile -Append -Encoding "ASCII" -NoTypeInformation


    #add the group information for users to the attributes file
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
    
    if($boolAttributeData)
    {
        $k=0
        foreach($attributeRow in $AttributeFile)
        {
            foreach($user in $uniqueUsers)
            {
                if($user[1].ToLower() -eq $attributeRow.userId)
                {
                     #Write-Host $user[1]
                    $row = New-Object System.Object
                    $row | Add-Member -MemberType NoteProperty -Name "userid" -Value $attributeRow.userId
                    $row | Add-Member -MemberType NoteProperty -Name "type" -Value $attributeRow.type
                    $row | Add-Member -MemberType NoteProperty -Name "value" -Value $attributeRow.value
    
                    $csvAttributes += $row
                    break
                }
            }
            $k +=1
            Write-Progress -Activity "Adding additional User attribute entries" -status "Updated $k rows from attribute file" -percentComplete ($k/$AttributeFile.Count*100)        
        }
    }
    else
    {
        #This is where specified attribute from settings file will be handled.
        $Attributes = $domain.Attributes.Attribute
        $LDAP = $domain.LDAP
        $Entry = New-Object System.DirectoryServices.DirectoryEntry($LDAP)
        $z=0
        foreach($user in $uniqueUsers)
        {
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
            $z+=1
            Write-Progress -Activity "Creating attribute rows" -status "Processed $z users" -percentComplete ($z/$uniqueUsers.Count*100)
        }
    }

    $attrFile = $Config.Settings.Directories.Output+"/"+$Name+"_attributes.csv"
    $csvAttributes | Export-Csv -Path $attrFile -Encoding "ASCII" -NoTypeInformation
        
    #$csvAttributes | Export-Csv -Path $attrFile -append -Encoding "ASCII" -NoTypeInformation

    $EndDate = Get-Date
    
    $ElapsedTime = New-TimeSpan -Start $StartDate -End $EndDate
    Write-Host "It took" $ElapsedTime "to run through the $Name domain."
}   

$OverallEnd = Get-Date

    $ElapsedTime = New-TimeSpan -Start $OverallStart -End $OverallEnd
    Write-Host "It took" $ElapsedTime "to run through the ODBC UDC file generation process."
