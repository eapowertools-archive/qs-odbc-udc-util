Function LogWrite()
{
    Param (
        [string]$Logfile,
        [string]$logstring
        )

    Write-Host $logstring
    Add-content $Logfile -value $logstring
}

Export-ModuleMember -Function LogWrite