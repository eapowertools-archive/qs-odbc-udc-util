
function getDomainUsers
{
    param(
        [xml]$Config,
        [System.Xml.XmlElement]$domain,
        [String]$LogFile
    )

    LogWrite $LogFile "Starting getDomainUsers on domain $($domain.Name)" 
    #This section builds the user files for each domain 
    #foreach($domain in $Domains)
    #{ 
        $Conn = $domain.LDAP
        $Paths = $domain.Paths.Path
        $csvUsers = @()
        $userFile = $Config.Settings.Directories.Output+"/"+$domain.Name+"_users.csv"
        #$csvUsers | Export-Csv -Path $userFile -Append -Encoding "ASCII" -NoTypeInformation
        

        #test LDAP Connection
        $testConn = "$Conn" + "RootDse"
        LogWrite $LogFile "Testing LDAP Connection to $Conn"
        $testLDAP = New-Object System.DirectoryServices.DirectoryEntry("$testConn")
        $testLDAP
        Trap
        {
            LogWrite $LogFile "$Conn is not available, ending user csv file generation for $($domain.Name)"
            exit
        }

        LogWrite $LogFile "Made it through"

        if($domain.Name -eq $Config.Settings.ServiceAccountDomain)
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
                LogWrite $LogFile "Processing this LDAP path: $FullConn"
        
            $Entry = New-Object System.DirectoryServices.DirectoryEntry("$FullConn")
            $LDAPFilter = "(objectClass=organizationalPerson)"
            $directorySearcher = New-Object System.DirectoryServices.DirectorySearcher($Entry, $LDAPFilter)

            $directorySearcher.PropertiesToLoad.Add("sAMAccountName")
            $directorySearcher.PropertiesToLoad.Add("name")
            $directorySearcher.SizeLimit = 0;
            $directorySearcher.PageSize = 500;
            $directorySearcher.SearchScope = "Subtree"

            try
            {

                $SearchResults = $directorySearcher.FindAll()

                LogWrite $LogFile "$Path has $($SearchResults.Count) users to add to the users files"
        
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
            }
            catch
            {
                LogWrite $LogFile "Found no users in Path: $FullConn"
                break
            }

            $EndDate = Get-Date

            $ElapsedTime = New-TimeSpan -Start $StartDate -End $EndDate
           LogWrite $LogFile "Finished in: $ElapsedTime"
        }   
    #}
    #End User file generation


}
