function getUniqueUsersByGroup([System.Collections.ArrayList]$domainUsers)
{
    $uniqueUsers = New-Object System.Collections.ArrayList
    $uniqueUsers = $domainUsers | Sort-Object @{Expression={$_[1]}; Ascending=$false} -Unique 

    

    return $uniqueUsers

}

Export-ModuleMember -Function getUniqueUsersByGroup