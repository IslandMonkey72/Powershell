##Author: John Watts HPE
##john-joseph.watts@hpe.com
## April 2025

##Purpose: takes a list of ADServers "ADServerList.csv" - created by script xxx and attempts to connect to each of the servers
## If a connection can be made, Information about the latest Patches are retrieved and output to the file "ServerInfoList.csv"



#Variables
$ReturnedOSInfo = @()
$date = get-date -Format ddMMyyyy
$time = get-date -Format HHmm



#get-credentials
$ADMCredentials = Get-Credential


#Setup output files for the results
$CSVServersInfoFileNameErrLog = "ServerInfoList" + "_" + $date + "_" + $time + ".err"
$CSVServersInfoFileName = "ServerInfoList" + "_" + $date + "_" + $time + ".csv"
$CSVServersInfoFilePath = "\\DE-INF-008\watts$\PowerShell_scripts\HyperV\"
$CSVServersInfoFilePathFull = $CSVServersInfoFilePath + $CSVServersInfoFileName
$CSVServersInfoFileErrLogPathFull = $CSVServersInfoFilePath + $CSVServersInfoFileNameErrLog

<#
if($CSVServersInfoFilePathFull){
	
	Remove-Item -Path $CSVServersInfoFilePathFull
	#write-host "$($CSVServersFile) has been deleted"
}
#>
#Import hosts




#Filter hosts
#Function get-servernames takes in a list of servers with information and if the file exists extracts the name of the server
function get-ServerNames{

	
	
	$Servers = @()
	
	write-output "START: get-ServerNames"
	
	#write-output "no of servers is:" $servers.length
	#write-output $servers[0]
	#write-output "servers at start of getservers function: $($servers)"
	
	#$ServerNames =@()
		
		#Check AD Host Information Exsists
		$CSVServersFileName = "ADServerList.csv"
		$CSVServersFilePath = "\\DE-INF-008\watts$\PowerShell_scripts\HyperV\"
		$CSVServersFilePathFull = $CSVServersFilePath + $CSVServersFileName
		$CSVServersFile = Get-ChildItem -Path $CSVServersFilePath -Filter $CSVServersFileName
		
		if($CSVServersFile){
			
			write-host "The file $($CSVServersFile) exists"
						
		}else{
		
			write-host "The file $($CSVServersFile) does not exist"
			exit
		}
		
		
		#Import hosts
		$csv = Import-Csv -Path $CSVServersFilePathFull -Delimiter ","
		
		
		write-output "before each object code"
			
		$csv | ForEach-Object{
			
			if($_ -ne $Null){
				
				write-output "$($_)Object found"
			}
			else{
				
				write-output "Object NOT found"
			}
					
			if(($_.OperatingSystem -like "*server*2016*") -or ($_.OperatingSystem -like "*server*2019*") -or ($_.OperatingSystem -like "*server*2022*") -or ($_.OperatingSystem -like "*server*2025*")){
				
				#$ServerNames += $_.name
				$Servers += $_.Name
				
				write-host "Object Reached"
				
				#write-host $_
				
				write-host "Server Name is $($_.Name)"
				write-host "$($_.name), $($_.OperatingSystem), $($_.LastlogonDate)"
			}
			#$ServerNames += $_.name
			
			
		}
		
		write-host "Servers length is $($servers.length)"
		
		write-output "After each object code"
		
		#write-host "Server Names"
		#write-host $ServerNames
		#return $ServerNames
			
		return $Servers
		
		write-output "END: get-ServerNames"
}

write-output "Servers are:"
write-output ""
write-output ""
write-output ""

$servers.name

#Find OS and Hostfix Information
## Funtions get-OSInformation checks the po


####Obsolete#########
$OSInfo = {
	
	function get-OSInformation{
		
		#$latestUpdate = "KB5055526"
		#$patched = "false"
		#$major = $PSVersionTable.psversion.Major
		#$minor = $PSVersionTable.psversion.Minor
		
		
		#$isInstalled = get-hotfix | Where-Object { $_.HotFixID -eq $latestUpdate }
		
		#if($isInstalled){
		#	$patched = "true"
		#}
		
		$hf = get-hotfix | select-object Hotfixid, Installedon | sort-object -property Hotfixid -Descending | select-object -First 1
		
		$cn = $env:ComputerName
		$hfid = $hf.HotfixID
		$hfio = $hf.InstalledOn
		
		#if(($major -ge 5) -and ($minor -ge 1)){
			$pn = Get-ComputerInfo | Select-Object WindowsProductName
			$compinfo = [PSCustomObject]@{ Hostname = $cn; ProductName = $pn.WindowsProductName; HotfixID = $hfid; InstalledOn = $hfio; Patched = $patched }
			write-host $compinfo
		#}else{
			#$pn = "Unknown"	
			#$compinfo = [PSCustomObject]@{ Hostname = $cn; ProductName = $pn; HotfixID = $hfid; InstalledOn = $hfio; Patched = $patched }
		#}
		
		return $compinfo		
	}
	#Run the function
	get-OSInformation
}


#Main control

$ServerHostNames = get-ServerNames



#Debug
<#
foreach($shn in  $ServerHostNames){
	
		write-host "Server Name is $($shn)"

}
#>

write-output "Number of servers: $($ServerHostNames.length)"


$i = 1


#Connect to Server and get OS Information
#Code here checks that the domain server name can be resolved.
#If it can be resolved, a connection is attempted using the above credentials.
#If unsuccessful, the error is logged in the ServerInfoList.err file.
#If a connecton can be made Information regarding the latest patch status is obtained to be output in a file
foreach($shn in $ServerHostNames){
	
	#write-host "Operating System is $($shn.OperatingSystem)"
	
	$hostname = $shn
	#$os = $shn.OperatingSystem
	
	$dnsname = Resolve-DnsName -name $hostname -ErrorAction "SilentlyContinue"
	$d = (Get-Date).tostring("dd.MM.yyyy hh:mm:ss")
	
	
	#Check if the server has a dns entry. If not it should be logged and checked.
	if($dnsname) {
		#Write-Output "DNS Name can be resolved"
		try {
				# Establish a remote session
				$ADsession = New-PSSession -ComputerName $hostname -Authentication Negotiate -Credential $ADMCredentials -ErrorAction "SilentlyContinue"
				if($ADsession){
					#Write-Output "$($shn) Connected ADServer"
				}else{
					#Write-Output "$($shn) Not Connected ADServer"
					#Write-Output "Please Check if $($shn) is a Windows machine"
					Write-Output "$($d) Unable to connect to Server $($hostname)" | Out-File -FilePath $CSVServersInfoFileErrLogPathFull -Append
					
				}
	
				# Run the command on the remote server
				Write-Output "$($i) of $($ServerHostNames.length) Getting information for $($hostname)..."
				$OSInformation = Invoke-Command -Session $ADsession -ScriptBlock $OSInfo
				$ReturnedOSInfo += $OSInformation
				
				
	
				# Output the result
				#Write-Output "Result from $($ClusterNodeName): $($result)"
	
				# Close the remote session
				Remove-PSSession -Session $ADsession
			} catch {
				Write-Error "Failed to connect to server: $($_) It may not be a windows server or it may be offline."
		}
	} else {
		Write-Output "$($d) $($shn): DNS name has no entry" | Out-File -FilePath $CSVServersInfoFileErrLogPathFull -Append
		#Add-Content -Path 
		
	}
	$i++
	
}
#write-host "Returned Info here:"


$ReturnedOSInfo | Export-CSV -Path $CSVServersInfoFilePathFull -Append -Delimiter "," -NoTypeInformation

#foreach($r in $ReturnedOSInfo){
	
	
#	write-host $r
#}

#write-host $Returned



