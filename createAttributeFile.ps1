$MyDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$Conn = "LDAP://qliktech.com/"
$Path = "OU=Users,OU=USA,DC=qliktech,DC=com"
$csvAttributes = @()
$attrFile = "$MyDir\qlikAttributeFile.csv"


$csvAttributes | Export-Csv -Path $attrFile -Encoding "ASCII" -NoTypeInformation

$FullConn = $Conn + $Path

$Entry = New-Object System.DirectoryServices.DirectoryEntry("$FullConn")
$LDAPFilter = "(objectClass=organizationalPerson)"
$directorySearcher = New-Object System.DirectoryServices.DirectorySearcher($Entry, $LDAPFilter)

$directorySearcher.PropertiesToLoad.Add("cn")
$directorySearcher.PropertiesToLoad.Add("name")
$directorySearcher.PropertiesToLoad.Add("mail")
$directorySearcher.SizeLimit = 0;
$directorySearcher.PageSize = 500;
$directorySearcher.SearchScope = "Subtree"

try
{

    $SearchResults = $directorySearcher.FindAll()
    Write-Host $SearchResults.Count

    $i=0
    $j=0
    foreach($result in $SearchResults)
    {
       # Write-Host $result.Properties
         $userId = $result.Properties["cn"]
         $displayname = $result.Properties["name"]
         $mail = $result.Properties["mail"] 

        if($mail -ne $null)
        {
            $row = New-Object System.Object
            $row | Add-Member -MemberType NoteProperty -Name "userid" -Value "$userId"
            $row | Add-Member -MemberType NoteProperty -Name "type" -Value "mail"
            $row | Add-Member -MemberType NoteProperty -Name "value" -Value "$mail"

    
            if($j -le 1000)
            {
                $csvAttributes += $row
                $j+=1
            }
            else
            {
                $csvAttributes | Export-Csv -Path $attrFile -Append -Encoding "ASCII" -NoTypeInformation
                $csvAttributes = @()
                $csvAttributes += $row
                $j=0
            }
            Clear-Item Variable:row

            $i+=1
        }
    }

    $csvAttributes | Export-Csv -Path $attrFile -Append -Encoding "ASCII" -NoTypeInformation
}
catch
{
    break
}