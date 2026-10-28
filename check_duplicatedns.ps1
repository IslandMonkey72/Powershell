##Author: John Watts HPE
##john-joseph.watts@hpe.Command
## Juni 2025

##Purpose: Checks for Duplicate DNS entries in from the UBA.BUND.DE Domain



$Domain = "UBA.BUND.DE"

#Variables
$Server = "DE-INF-081.uba.bund.de"  #Virtual AD Server
#$CSVServersFile = "\\DE-INF-008\watts$\PowerShell_scripts\HyperV\Hermes-ADServerList.csv"
$CSVServersFile = "\\DE-INF-008\watts$\PowerShell_scripts\HyperV\DNSServerList.csv"

#if($CSVServersFile){
	#Remove-Item -Path $CSVServersFile
	##write-host "$($CSVServersFile) has been deleted"
#}



$DNSEntries = Get-DnsServerResourceRecord -ComputerName $Server -ZoneName $Domain | Where-Object { $_.RecordType -eq "A"} | Select-Object HostName, RecordType, @{Name="IPAddress";Expression={$_.RecordData.IPv4Address}}



#write-host "$($DNSEntries.HostName)"


#$DNSEntries | Export-Csv -Path $CSVServersFile -Append -NoTypeInformation -Force


$DNSIPs = @()

foreach ($ip in $DNSEntries){
	
		$DNSIPs += $ip.IPAddress.IPAddressToString
		
		#$DNSIPs
	
}

$NoOfIPs = $DNSIPs.length


for($i=0; $i -lt $NoOfIPs; $i++){
	
		
}

$NoOfIPs = $DNSIPs.length

#write-host "Number of entries is: $($DNSIPs.length)"
$count = 0

for($i=0; $i -lt $NoOfIPs; $i++){

	for($j=0; $j -lt $NoOfIPs; $j++){
		
		if (-not $i -eq $j ){
		
			if($DNSIPs[$i] -eq $DNSIPs[$j]){
				
				write-host "Duplicate Entry found $($DNSIPs[$i]) : i is $($i) and j is $($j)"
				write-host "$($DNSEntries[$i].HostName)"
			}
		}
		$count++
		
	}

}

write-host "Count: $($Count)"
