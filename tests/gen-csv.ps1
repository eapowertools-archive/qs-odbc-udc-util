$csv = @()

$row = New-Object System.Object
$row | Add-Member -MemberType NoteProperty -Name "userid" -Value "jog"
$row | Add-Member -MemberType NoteProperty -Name "type" -Value "group"
$row | Add-Member -MemberType NoteProperty -Name "value" -Value "foo"

$csv += $row

$row = New-Object System.Object
$row | Add-Member -MemberType NoteProperty -Name "userid" -Value "msi"
$row | Add-Member -MemberType NoteProperty -Name "type" -Value "group"
$row | Add-Member -MemberType NoteProperty -Name "value" -Value "bar"


$csv += $row

$csv | Export-Csv -Path "f:\my documents\_git\qs-odbc-udc-util\tests\testoutput.csv" -Encoding "UTF8" -NoTypeInformation


