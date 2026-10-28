##Author: John Watts HPE
##john-joseph.watts@hpe.Command
## April 2025

##Purpose: Outputs a list of ADServers "ADServerList.csv" - to be used by furter scripts




Import-Module ActiveDirectory

#Variables
$ADSource = "DE-INF-081.uba.bund.de"  #Virtual AD Server
#$CSVServersFile = "\\DE-INF-008\watts$\PowerShell_scripts\HyperV\Hermes-ADServerList.csv"
$CSVServersFile = "\\DE-INF-008\watts$\PowerShell_scripts\HyperV\ADServerList.csv"

#if($CSVServersFile){
	#Remove-Item -Path $CSVServersFile
	##write-host "$($CSVServersFile) has been deleted"
#}


#Ask for Credentials
$Credential = get-credential



#Find all Systems to parse
$ADCommand = {
	function Get-Servers {
		
	
		#$CSVServersFile = "\\DE-INF-008\watts$\PowerShell_scripts\HyperV\ADServerList.csv"
		
		if($CSVServersFile){
			Remove-Item -Path $CSVServersFile
			#write-host "$($CSVServersFile) has been deleted"
		}

		
		$i = 0
		#Includes uba.de and uba.bund.de
		#$domain = "hermes-de11.uba.de"
		$domain = "DE-INF-081.UBA.BUND.DE"
		#$Servers = @(Get-ADComputer -filter * -Properties * | Select Name, OperatingSystem)
		#$Servers = @(Get-ADComputer -Filter {OperatingSystem -like "*Windows*Server*"} -Server $domain  -Properties Name, OperatingSystem  )
		
		$Servers = @(Get-ADcomputer -filter * -Properties * | Select Name, OperatingSystem, lastLogondate, IPv4Address)  # | where OperatingSystem  -like "*server*")
		#Get-ADComputer -Filter {OperatingSystem -like "*Server*"} | Export-CSV $CSVServersFile -Append -NoTypeInformation
		#$Servers = Get-ADComputer -Filter * -Property Name, OperatingSystem {Name -like "*"}
		#write-output "Number of Servers from AD is: $($Servers.length)`r`n"
		#write-host $Servers
		#$ADServer = @()
		#foreach($Server in $Servers){
		
		
		
		#write-output "The Number of Filtered Servers is $($i)"
		#write-host $ADServers
		return $Servers # $Servers
	}
	#Run the function
	Get-Servers
}

#Connect to AD and get list of servers
try {
        # Establish a remote session
	    $ADsession = New-PSSession -ComputerName $ADSource -Credential $Credential
		if($ADsession){
			Write-Output "Connected ADServer"
		}else{
			Write-Output "Not Connected ADServer"
		}

	    # Run the command on the remote server
        $ADItems = Invoke-Command -Session $ADsession -ScriptBlock $ADCommand

	    # Output the result
        #Write-Output "Result from $($ClusterNodeName): $($result)"

	    # Close the remote session
		Remove-PSSession -Session $ADsession
	} catch {
		Write-Error "Failed to connect to $($server): $($_)"
}	



#write-host $ADsession

#write-output $ADItems
#$ADItems.length

#foreach($ad in $ADItems){

#	write-output "The value of $r is: $($ad.Name)"
	#$ad.Name, $ad.ObjectClass, $ad.OperatingSystem, $ad.PSComputerName, $ad.RunspaceId | Export-Csv $CSVServersFile -Append -NoTypeInformation
#}


$ADItems | Export-Csv -Path $CSVServersFile -Append -Delimiter "," -NoTypeInformation -Force


write-host "There are $($ADItems.length) Servers in the AD" 
#Write-Output "ServerNames from Array: "
#foreach($s in $ServerNames)
#{
#     Write-Output "ServerName from Array: $($s)"
#}
#Write-Output "Servers: $($Servers)"

#Connect to AD and get list of servers




#Test Case - Filter out Test Systems in Dessau

#servers = Get-ADComputer -Filter {OperatingSystem -like "*Server*"} -Property Name, OperatingSystem



