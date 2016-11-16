$MyDir = Split-Path -Parent $MyInvocation.MyCommand.Path

[xml]$Config = Get-Content "$MyDir\Settings.xml"

if($Config.Settings.Security.UserId)
{
    Write-Host Hey $Config.Settings.Security.UserId
}
else {
    Write-Host You Suck
}