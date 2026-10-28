#Get Last Login to AD from Servers
Import-Module ActiveDirectory


#
$Credential = get-credential
$ADServer = "DE-MAN-081"
$Domain = "hermes-de11.uba.de"
$ServerADInfo = $null
#$CSVServersFile = "\\DE-INF-008\watts$\PowerShell_scripts\HyperV\Hermes-ADServerList.csv"


#$csv = Import-Csv -Path $CSVServersFile

#get file of server list and parse

$Servers = @(Get-ADComputer -Filter {OperatingSystem -like "*Windows*Server*"} -Server $Domain  -Properties Name, OperatingSystem -Credential $Credential )

foreach($Server in $Servers) {
	
	$ServerADInfo = (Get-ADComputer $Server.Name -Properties * -Credential $Credential)
	
	write-output "$($Server) last logged into the AD Server on $($ServerADInfo.lastlogondate)"
}

#find lastlogin on the AD


#Outputresults to csv file