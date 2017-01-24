

function genQlikGroupUserList([xml]$Config, [string]$LogFile)
{

    $users = New-Object System.Collections.ArrayList

    #obtain the server instances from the settings file.
    $Servers = $Config.Settings.LDAP.Servers.Server

    #for each server, create a directory entry and get the group list
    foreach($server in $Servers)
    {
        $Conn = $server.LDAP
        $Name = $server.Name
        LogWrite $LogFile "Getting group list for $Name"

        foreach($path in $server.Paths.Path)
        {
            $FullConn = $Conn + $path
            LogWrite $LogFile "Connecting to $FullConn"
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
                LogWrite $LogFile "Processing $GroupMember"
                $LDAPFilter = "(&(objectClass=group)(cn=$GroupMember))"
                
                # Setup range limits.
                $Last = $False
                $RangeStep = 999
                $LowRange = 0
                $HighRange = $LowRange + $RangeStep
                $Total = 0
                $ExitFlag = $False

                Do
                {
                    If ($Last -eq $True)
                    {
                        # Retrieve remaining members (less than 1000).
                        $Attributes = "member;range=$LowRange-*"
                    }
                    Else
                    {
                        # Retrieve 1000 members.
                        $Attributes = "member;range=$LowRange-$HighRange"
                    }
                    LogWrite $LogFile "Retrieving $attributes"
                    # Write-Host $Attributes
                    # Write-Host "Press any key to continue ..."
                    # $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

                    $directorySearcher = New-Object System.DirectoryServices.DirectorySearcher($Entry, $LDAPFilter)
                    $directorySearcher.SizeLimit = 0;
                    $directorySearcher.PageSize = 500;
                    $directorySearcher.SearchScope = "Subtree"

                    $directorySearcher.PropertiesToLoad.Add("$Attributes")
                    try {
                        $SearchResults = $directorySearcher.FindAll()
                        $Count = 0

                        foreach($property in $SearchResults.Properties.PropertyNames)
                        {
                            #$property
                            if($property.StartsWith("member"))
                            {
    #                            if(($SearchResults.Properties[$property].Count -gt 0) -or 
     #                               ($SearchResults.Properties[$property].Count -ne $null))
      #                          {
                                    #$SearchCount = $SearchResults.Properties[$property].Count
                                    foreach($member in $SearchResults.Properties[$property])
                                    {
                                        #Write-Host "$Count|$member"
                                        $Count = $Count + 1
                                        $udc = $member -split ",DC="
                                        $udc = $udc[1]
                                        $uid = $member -split ","
                                        $uid = $uid[0].SubString(3,$uid[0].length -3)
                                        $users.Add(@($udc,$uid,$GroupMember,$member)) > $null
                                    }
       #                         }
                            }
                        }    
                    
                        Remove-Variable directorySearcher
                        Remove-Variable SearchResults
                    }
                    catch {
                        LogWrite $LogFile "No Results found for $GroupMember"
                        break
                    }

        
                    $Total = $Total + $Count

                    # If this is the last query, exit the Do loop.
                    If ($Last -eq $True) {
                        $ExitFlag = $True
                        }
                    Else
                    {
                        # If the previous query returned no members, the query failed.
                        # Perform one more query to retrieve remaining members (less than 1000).
                        If ($Count -eq 0) {$Last = $True}
                        Else
                        {
                            # Retrieve the next 1000 members.
                            $LowRange = $HighRange + 1
                            $HighRange = $LowRange + $RangeStep
                        }
                    }
                } Until ($ExitFlag -eq $True)


               LogWrite $LogFile "$GroupMember Total records created: $Total"
                $i+=1
                #Write-Progress -Activity "Processed Group: $GroupMember" -status "Processed $i Groups" -percentComplete ($i/$GroupList.Count*100)                       
            }
        }
    } 

    LogWrite $LogFile "Completed genQlikGroupUserList"
    Write-Host $users.Count
    return ,$users
}

Export-ModuleMember -Function genQlikGroupUserList
