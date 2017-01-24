function genAttributeFiles
{
    param(
        [xml]$Config,
        [System.Collections.ArrayList]$uniqueUsers,
        [System.Xml.XmlElement]$domain,
        [String]$LogFile
    )

    LogWrite $LogFile "Creating Attribute File for $($domain.Name)" 
    $csvAttributes = @()
    $StartDate = Get-Date
    #Begin Group Definition Section
    #for an attribute file that contains additional attributes to add to the attribute file per domain.
    if($Config.Settings.Files.AttributeData)
    {
        $AttributeFile = Import-Csv $Config.Settings.Files.AttributeData
        $boolAttributeData = $true
    }

    $boolAttributeData

    $uniqueUsers.Count

    if($boolAttributeData)
    {
        LogWrite $LogFile "Using an attribute data file provided to the runner." 
    
        $k=0
        foreach($attributeRow in $AttributeFile)
        {
            $l = 0
            foreach($user in $uniqueUsers)
            {
                if($user[1].ToLower() -eq $attributeRow.userId)
                {
                    $row = New-Object System.Object
                    $row | Add-Member -MemberType NoteProperty -Name "userid" -Value $attributeRow.userId
                    $row | Add-Member -MemberType NoteProperty -Name "type" -Value $attributeRow.type
                    $row | Add-Member -MemberType NoteProperty -Name "value" -Value $attributeRow.value
    
                    $csvAttributes += $row
                    Clear-Item Variable:row
                    break
                }
                $l+=1
            }

            $k +=1
            #Write-Progress -Activity "Adding additional User attribute entries" -status "Updated $k rows from attribute file" -percentComplete ($k/$AttributeFile.Count*100)        
        }
    }
    else
    {
        LogWrite $LogFile "Attributes provided in the settings file"
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
            #Write-Progress -Activity "Creating attribute rows" -status "Processed $z users" -percentComplete ($z/$uniqueUsers.Count*100)
        }
    }

    $attrFile = $Config.Settings.Directories.Output+"/"+$domain.Name+"_attributes.csv"
    $csvAttributes | Export-Csv -Path $attrFile -Append -Encoding "ASCII" -NoTypeInformation
        
    #$csvAttributes | Export-Csv -Path $attrFile -append -Encoding "ASCII" -NoTypeInformation

    $EndDate = Get-Date
    
    $ElapsedTime = New-TimeSpan -Start $StartDate -End $EndDate
    LogWrite $LogFile "It took" $ElapsedTime "to run through genAttributeFiles for the" $domain.Name "domain."
    
}