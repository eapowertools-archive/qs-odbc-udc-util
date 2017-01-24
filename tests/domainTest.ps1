$MyDir = Split-Path -Parent $MyInvocation.MyCommand.Path
 
[xml]$Config = Get-Content "$MyDir\Settings.xml"

#Domains to check
$Domains = $Config.Settings.Domains.Domain



foreach($domain in $Domains)
{
    
    $domain.Name
    $domain.LDAP
    $Attributes = $domain.Attributes.Attribute
    foreach($attribute in $Attributes)
    {
        $attribute
    }
}