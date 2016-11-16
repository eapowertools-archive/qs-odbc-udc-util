$response = Get-AdUser -Filter {(Company -eq "112adams")}
$count = 0
foreach ($item in $response)
{
    $count = $count +1
    if($count -le 10)
    {
       Add-ADGroupMember -identity "Finance" -Members $item
    }
    if($count -gt 10 -and $count -le 20)
    {
       Add-ADGroupMember -identity "Marketing" -Members $item
    }
    if($count -gt 20 -and $count -le 30)
    {
       Add-ADGroupMember -identity "Sales" -Members $item
    }

}

