


$win2008 = Get-ADComputer -Filter * -Properties OperatingSystem | Select-Object Name, OperatingSystem | Where-Object {$_.OperatingSystem -Like "*server 2008*"}
$win2012 = Get-ADComputer -Filter * -Properties OperatingSystem | Select-Object Name, OperatingSystem | Where-Object {$_.OperatingSystem -Like "*server 2012*"}
$win2016 = Get-ADComputer -Filter * -Properties OperatingSystem | Select-Object Name, OperatingSystem | Where-Object {$_.OperatingSystem -Like "*server 2016*"}
$win2019 = Get-ADComputer -Filter * -Properties OperatingSystem | Select-Object Name, OperatingSystem | Where-Object {$_.OperatingSystem -Like "*server 2019*"}
$win2022 = Get-ADComputer -Filter * -Properties OperatingSystem | Select-Object Name, OperatingSystem | Where-Object {$_.OperatingSystem -Like "*server 2022*"}
$win2025 = Get-ADComputer -Filter * -Properties OperatingSystem | Select-Object Name, OperatingSystem | Where-Object {$_.OperatingSystem -Like "*server 2025*"}