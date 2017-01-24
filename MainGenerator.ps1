Param(
    [string]$domainParam
)
if($domainParam -eq $Null -or $domainParam -eq "")
{
    $domain_Error = [string]"Please enter a domain name as an argument for this script"
    throw $domain_Error
}
else {
    Write-Host $domainParam
}

$OverallStart = Get-Date


$MyDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$LogTime = Get-Date -Format "MM-dd-yyyy_hh-mm-ss"
$Logfile = "$MyDir\logs\qs-odbc-udc-util_$LogTime.log"

Import-Module -Name "$MyDir\logger.psm1" -Force
Import-Module -Name "$MyDir\genQlikGroupUserList.psm1" -Force
Import-Module -Name "$MyDir\getDomainUsersByGroup.psm1" -Force
Import-Module -Name "$MyDir\getUniqueUsersByGroup.psm1" -Force
Import-Module -Name "$MyDir\addQlikGroupUsers.psm1" -Force
Import-Module -Name "$MyDir\getDomainUsers.psm1" -Force
Import-Module -Name "$MyDir\genAttributeFiles.psm1" -Force

#instantiate logger
LogWrite $LogFile "Starting up user and attribute file creation for domain $domainParam"
LogWrite $LogFile "Started at $OverallStart"


#load configuration file
[xml]$Config = Get-Content "$MyDir\Settings.xml"
LogWrite $LogFile "Loaded Settings.xml file"


#Generate user arraylist of members from specified global groups
$users = genQlikGroupUserList $Config $LogFile
$usersNeo = $users[$users.Count-1]



#Domains to check
$Domains = $Config.Settings.Domains.Domain

$domain = $Null

foreach($val in $Domains)
{
    if($val.Name -eq $domainParam)
    {
        LogWrite $LogFile "$domainParam found in settings file.  Processing against $domainParam"
        $domain = $val
        break
    }
}
if($domain -eq $Null)
{
    $domainNotFound_Error = [string]"The domain value entered as argument was not found"
    throw $domainNotFound_Error
}



LogWrite $LogFile "Getting domain users from group generated list"
$domainUsers = getDomainUsersByGroup $usersNeo $domain.Name

Write-Host $domainUsers.Count

LogWrite $LogFile "Found $($domainUsers.Count) domain users from group generated list"

LogWrite $LogFile "Getting unique users from group generated list"
$uniqueUsers = getUniqueUsersByGroup $domainUsers

LogWrite $LogFile "Found $($uniqueUsers.Count) unique users from group generated list"


#test LDAP Connection
$Conn = $domain.LDAP
$testConn = "$Conn" + "RootDse"
LogWrite $LogFile "Testing LDAP Connection to $Conn"
$testLDAP = New-Object System.DirectoryServices.DirectoryEntry("$testConn")
$testLDAP
Trap
{
    LogWrite $LogFile "$Conn is not available, ending user csv file generation for $($domain.Name)"
    exit
}


addQlikGroupUsers $Config $domainUsers $uniqueUsers $domain.Name $LogFile

Write-Host $domain.GetType()
getDomainUsers $Config $domain $LogFile


genAttributeFiles $Config $uniqueUsers $domain $LogFile

$OverallEnd = Get-Date

$ElapsedTime = New-TimeSpan -Start $OverallStart -End $OverallEnd

LogWrite $LogFile "Process completed for $($domain.Name) in $ElapsedTime"
    