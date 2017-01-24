function getDomainUsersByGroup([System.Collections.ArrayList]$users, $domain)
{
    
    $domainUsers = New-Object System.Collections.ArrayList
    
    $domainUsers = $users | Where-Object {$_[0] -eq $domain}
    return $domainUsers

}

Export-ModuleMember -Function getDomainUsersByGroup