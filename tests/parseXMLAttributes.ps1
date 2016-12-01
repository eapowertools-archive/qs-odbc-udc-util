$MyDir = Split-Path -Parent $MyInvocation.MyCommand.Path
 
[xml]$Config = Get-Content "$MyDir\Settings.xml"

#$Servers =  $Config.Settings.LDAP.Servers

#$Config.Settings.LDAP.Servers


$foo = $Config.Settings | Format-Table -AutoSize

$Servers = $Config.Settings.LDAP.Servers.Server

#$Servers

foreach($server in $Servers)
{
    foreach($group in $server.Groups.Group)
    {
        #$group
        #$group.'#text'
        if($group.type -eq "file")
        {
            $Groups = Import-Csv $group.'#text' -Header "Groups"
            $Groups = $Groups.Groups
        }
        else
        {
            $Groups += $group.'#text'    
        }

        $Groups

    }
}

# foreach($server in $Config.Settings.LDAP.Servers)
# {
#     $server.Groups
#     # foreach($group in $server)
#     # {
#     #     $group
#     # }
# }