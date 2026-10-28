<# 28. August 2025

Description of actions:

Aim of script. Copy the top level structure directories from a target DFS Server with their properties i.e. Quotas and ACL.

The folders will be then created on two new machines, they are the replacement DFS Server and the central DFS Server in BW.

Following this, the servers will be used to create a DFS-R Construct in order to maintain a replication of the services.

Requirements are that the source server is available and that the two target servers are available and have the mount points created:

On the central target Server this is \\BW-INF-025\g:\

On the Local Server (Replacement for Windows 2012) the new location is <site abbreviation>-INF-025\g$\DSFR-<site abbreviation>

e.g. For Marienfelder it is MF-INF-025\g$\DSFR-MF


High Level Overview of the migration.

	i. DFSR-Replication (1 Central Hub, 5 Remote Spokes)
	ii. Transfer SMB-Shares including Quotas and their templates
	iii. Automation via Powershell
	iv. Data Copy via Robocopy or similar
	v. New Namespace


1.From the source system:

	i. Get the top level directories
	ii. Get the Quota from the directories
	iii. Get the ACLs for the directories 
	
2. Apply these to the new servers


	Read out the shared folders on current server
		Get-ChildItem / get-SMBShare


	Read/Save NTFS Permissions for the shares
		Get-ACL
	
	Read Quotas
		Get-FsrmQuota
		
		
		
	Create shares on new Server
		New-SMBShare
		
	
	
Requirements:


Powershell version 5 oder höher


FSRM Tools Auf den Clients installiert

Install-WindowsFeature -Name FS-Resource-Manager -IncludeManagementTools

Check share is active on G an H


#>




#############################################################Variables#############################################################

$ServerABBR = "GAW"

$ReplicationServer = "BW-INF-025"
$NewDFSServer = $ServerABBR + "-INF-025"
#$NewDFSServer = "GAW-INF-025"
$SourceServer = $ServerABBR + "-INF-002"
#$SourceServer = "GAW-INF-002"
$DFSRFolder = "DFSR-" + $ServerABBR 
$QuotaTemplates = @()

#write-host "X=================X"
#$NewDFSServer
#$SourceServer 
#write-host "X=================X"

#Group Share Variables
$GroupRootPaths = @()
$ReplicationFolders = @()
$GroupDrive = 'G:'
#$GroupDriveShare = '\g$\'
$GroupSourceFolder = "Gruppen" + $ServerABBR
#$GroupFolders = Get-ChildItem -Depth 1 -Recurse "\\$($SourceServer)$($GroupDriveShare)"

$SourceGroupFoldersLocation = $GroupDrive + "\" + $GroupSourceFolder


#User Share Variables
$UserRootPaths = @()
$UserDrive = 'H:\'
#$UserDriveShare = '\h$\'
$UserSourceFolder = "Home" + $ServerABBR
#$UserFolders = Get-ChildItem -Depth 1 -Recurse "\\$($SourceServer)$($UserDriveShare)"



#Variables for Arrays
$AllSourceServerTemplatesEdited = @()
$AllDestinationServerTemplatesEdited = @()



$TargetCentral = '\\' + $ServerCentral + $DriveLetter
$TargetLocal = '\\' + $ServerLocal + $DriveLetter + 'DFSR-' + $ServerABBR + '\'
$Source = '\\' + $SourceServer + $DriveLetter     #.Replace('$',':')
$GroupSourceFolder = "Gruppen" + $ServerABBR
$UserSourceFolder = "Home" + $ServerABBR


#Get the folder list for the server with the local path on the server and removes the Home / Group Folder
$GroupFolders = $GroupFolders | Where-Object -Property Parent -like "*$GroupSourceFolder*"
#$GroupFolders = $GroupFolders | Where-Object -Property Parent -like "*Gruppen*$($ServerABBR)*"
$UserFolders = $UserFolders | Where-Object -Property Parent -like "*Home$($ServerABBR)*"






#Create Group Folder Root Paths local to the Server
foreach($GroupFolder in $GroupFolders){
	
	$SGroupRootPaths += $GroupDrive + $GroupSourceFolder + '\' + $GroupFolder.name
	$TGroupRootPaths += $GroupDrive + $GroupFolder.name
}



#Create User Folder Root Paths local to the Server
foreach($UserFolder in $UserFolders){
	
	$SUserRootPaths += $UserDrive + $UserSourceFolder + '\' + $UserFolder.name
	$TUserRootPaths += $UserDrive + $UserFolder.name
}


####################Function Definitions#############################



################################Remote ScriptBlock Code Start############################
#
#
################################Get and Set Directories - Start############################
$ScriptBlockCheckFSRM = {
	
	$ImpFSRM = Install-WindowsFeature -Name FS-Resource-Manager -IncludeManagementTools
	
	return $ImpFSRM
		
}

$ScriptBlockReadDirectories = {
	
	$DirNames = @()
	
	if($args.Length -gt 1){
		
		Write-host "There are too many paths to read from on the source Server"
		Exit 1
	}
	
	if(-not (Test-Path $args)){
	
		write-host "The Path $($args) does not exist on the server Please check and try again"
		Exit 1
	}
	
	
	#write-host "ScriptBlockReadDirectories args $($args)"
	
	$dirs = get-childitem $args
	
	foreach($dir in $dirs){
		$DirNames += $dir.name
		
	}
	
	return $DirNames
}


$ScriptBlockWriteDirectories = {
	
	#Variable to return the new folder locations
	$FullPaths = @()
	
	$Drive = $args[0]
	$Dirs = $args[1]
	
	foreach($Dir in $Dirs){
		
		$FullPath = $Drive + $Dir
		$FullPaths += $FullPath
		#write-host "tmpGroupRootPath is $($tmpGroupRootPath )"
		
		if(-not (Test-Path $FullPath)){

			New-Item -ItemType Directory -Path $FullPath
		}else{
			Write-host "$($FullPath) Already Exists"
		}
		
	}
	
	return $FullPaths
}


################################Get and Set Directories - End############################
#
#
################################Get and Set Quota Templates - Start############################


#Get Quota Template Info
$ScriptBlockGetFSRMQuotaTemplates = {
	
	#Write-host "SCriptblock reached"
	$Templates = @()
		
	$Templates = get-FsrmQuotaTemplate

	return $Templates
}


$ScriptBlockSetFSRMQuotaTemplates = {

	$templates = get-FsrmQuotaTemplate
	
	try{
		foreach($fqt in $args){
			if(-not(Get-FsrmQuotaTemplate -Name $fqt.name -ErrorAction SilentlyContinue)){
					New-FsrmQuotaTemplate -Name $fqt.name -Description $fqt.Description -Size $fqt.size
			}else{
				write-host "$($fqt.name) exists"
			}
		}	
	}catch{
		Write-Warning "Fehler beim Setzen der Quota für $($fqt.name)"
	}
}


################################Get and Set Quota Templates - End############################
#
#
################################Get and Set Quotas - Start############################

#Return the Quotas for the top level folders on the remote server
$ScriptBlockGetQuotas = {
	
	#Write-host "SCriptblock reached"
	$Quotas = @()
	$NoQuotas = @()
	
	
	
	foreach($arg in $args){
		
		try{
			$tmp = Get-FsrmQuota -path $arg -ErrorAction SilentlyContinue
		}catch{
			
			write-host"Error getting Quota" 
		
		}
		#write-host 'Get-FsrmQuota -path ' $arg
		if($tmp){
			$Quotas += $tmp
		}else{
			#write-host "$($arg) `t has no Quota assigned"
			$NoQuotas += $arg
		}
	}
	return @($Quotas, $NoQuotas)
}

######

$ScriptBlockSetQuotas = {
	
	
	Import-Module FileServerResourceManager
	
	<#
	Quotas im DFS-R-Kontext
	Wichtig: Quotas (FSRM) gelten lokal auf jedem Server. Da DFS-R auf NTFS-Ebene repliziert, musst du Quotas manuell oder geskriptet auf allen Replikatservern konfigurieren.
	 
	New-FsrmQuota -Path "D:\Daten" -Size 100GB -Template "StandardQuota"
	Quotas müssen überall gleich konfiguriert werden, sonst kommt es zu unterschiedlichen Nutzungsgrenzen.
	-> hierfür sollten wir dann ein script bauen, was für IT-OPS genutzt wird (tickets für vergößerung gruppenLW oder HomeLW)
	#>
	
	<#
	check if there is a quota on the path and if not create a new one based on the import 
	
	if it exists use the set cmdet
	#>
	
	
	
	foreach($quota in $args){
			
			
			$threshold = $quota.threshold.percentage
			
			
			$test_templ = Get-FsrmQuotaTemplate -Name $quota.Template
			
			#write-host "Quota Template from Templates":
			#write-host $test_templ
			
			#write-host "Path from Quota":
			#write-host $quota.path
			
			
		
			$path = $quota.path
			write-host "Get-FsrmQuotaTemplate will be checked"
			
			Write-Warning "Fehler beim holen das template objekt für $($quota.template) "
		
		try{
			if((Get-FsrmQuotaTemplate -Name $quota.Template -ErrorAction SilentlyContinue) -and (Test-Path -Path $path)){
				
				#Write-Host "Entered the  FsrmQuotaTemplate and path test"
				#if the a quota for the path exists, overwrite it with the imported values or else create an new quota
				#if(-not(Get-FsrmQuota -path $path)){
				if(-not(Get-FsrmQuota | where-object { $_.path -like $path })){
						Write-Host "Quota not Found from path: $($quota).path"
					try{
						#New-FsrmQuota -Path $path -Size $quota.size -Softlimit:$quota.softlimit -Threshold $threshold -Template $quota.template -ErrorAction Stop | Out-Null
						New-FsrmQuota -Path $path -Size $quota.size -Softlimit:$quota.softlimit -Template $quota.template -ErrorAction Stop | Out-Null
						
						Write-Host "Quota has been set $($quota).path"
					}catch{
						Write-Warning "Fehler beim Setzen der Quota New-FSRMQuota"
					}
				}else{
					Write-Host "***Quota for the path: $($quota).path - Already exists***"
				}
			}else{ 
				Write-Host "Either the Path $($quota.path) or the template $($quota.template) does not exist on the system" 
		
			}
		}catch{
			#Write-Warning "Fehler beim Setzen der Quota für Path: $quota.path"
			Write-Warning "Fehler beim Setzen der Quota für Path: $quota"
			write-host "$($_.ErrorDetails.Message)"
		}
	}
}

################################Get and Set Quotas - Start############################
#
#
################################Get and Set SMB Shares - Start############################

#Get SMBShares for folders
$ScriptBlockGetSMBShares = {
	
	$SMBShares = @()
	$NoSMBShares = @()
	
	foreach($path in $args){
		
		$SMBShare = Get-SMBShare | where-object -Property path -like $path
		#write-host 'get-SMBShare | where-object -Property path -like '  $arg
		
		if($SMBShare){
			
			$SMBShares += $SMBShare
	
		}else{
		
			#write-host "$($arg) `t has no SMB Share assigned"
			$NoSMBShares += $path
		}
	}
	return @($SMBShares, $NoSMBShares)
}



$ScriptBlockSetSMBShares = {
	
	$ExistingShares = @()
		
	foreach($SMBShare in $args){
			
		$Sharename = $SMBShare.name
		$Sharepath = $SMBShare.path
					
		#Create Path if it does not exist
		if(-Not(Test-Path $Sharepath)){
			write-host "Share Path does not exist: $($Sharepath)"
			New-Item -Path $Sharepath -ItemType Directory
		}
		
		#check if SMBShare exists on server to be written on
		if(-Not(Get-SMBShare -Name $Sharename)){
			
			write-host "Created SMBShare $($ShareName) on the path $($Path)"
			New-SmbShare -Name $($ShareName) -Path $($Path) -FullAccess 'jeder'
		}else{
			#write-host "SMB Share Exists: $($Sharename)"
			$ExistingShares += $SMBShare
		}
	}
}

################################Get and Set SMB Shares - End############################
#
#
################################Get and Set NTFS Permissions (ACL) - Start############################

#Return the ACLs for the top level folders on the remote server
$ScriptBlockGetACLInfo = {
	
	$ACLs = @()
	
	$root = $args[0]
	$dirs = $args[1]
	
	#write-host "Root path $($root)"
	
	
	foreach($dir in $dirs){
		
		
		$path = $root + "\" + $dir
		
		#write-host "Obtaining ACLs for $($Path)"
		
		$acl = get-acl -path $path
	
		$ACLs += $acl
		#write-host "ACLs has had an acl assigned" -foregroundcolor Blue
	}
	
	write-host "GetACL: ACLs Length in Get Function is: $($ACLs.length)" -foregroundcolor Green
	
	return $ACLs
}



$ScriptBlockSetACLInfo = {

	
	
	#$paths = @()
	$ACLs = @()
	
	#$paths = $args[0]
	$ACLs = $args
	#$count = 0
	#write-host "length of paths is $($paths.length)" -foregroundcolor Green
	#write-host "length of ACLs is $($ACLs.length)" -foregroundcolor Blue
	
	foreach($ACL in $ACLs){
	
		#Need to remove GruppenXX / HomeXX
		
		#Extract the path
		$Path = ($ACL.Path.ToString() -split "::")[-1]
		
		write-host "ScriptBlockSetACLInfo:  path before editing $($Path)"
		
		#write-host "ACL Access is $($ACL.Access.count)"
		#write-host "ACL Access is $($ACL.FileSystemRights)"
		#write-host "ACL Access is $($ACL.AccessControlType)"
		#write-host "ACL Access is $($ACL.IdentityReference)"
		#write-host "ACL Access is $($ACL.InheritanceFlags)"
		#write-host "ACL Access is $($ACL.PropogationFlags)"
		
		#Split String to see if more than two components and if so remove the "GruppenXX / HomeXX" folder
		if($Path.Split("\").Length -gt 2){
			
			$NewPath = $Path.Split("\")[0] + "\" + $Path.Split("\")[2]
			write-host "ScriptBlockSetACLInfo: Setting ACL on path $($NewPath)"
		}
		try{
			$test = set-acl -path $NewPath -AclObject $ACL
			
			write-host "NewPath Access is $($NewPath)"
			write-host "ACL Access is $($ACL)"
			
			
			write-host "Lastexitcode: $($lastexitcode)"
			
			if($?){
				write-host "ACL successfully set"
			}else{
				write-host "ACL NOT Set"
			}
			
			
			
		}catch{
			"Unable to Assign the ACL on path $($NewPath)"
		}
		#write-host "Set-Acl -Path $($NewPath) -AclObject $($ACL)"
		#write-host "SetACL: ACL set on path: $($NewPath)" set-foregroundcolor Green
		
		#$count++
	
	}
	
	
	
}
################################Get and Set NTFS Permissions (ACL) - END############################
#
#
################################Remote ScriptBlock Code END############################
#
#
################################Invocation: Get Information from the current Server - START############################


#Test if FSRM Installed on Target server
$ImpFSRM = Invoke-Command -ComputerName $NewDFSServer -Scriptblock $ScriptBlockCheckFSRM

if(-not ($ImpFSRM.Success)){
		
		write-host "The FSRM Module was not loaded on the server. Please check and try again"
		Exit 1
}


$ReadGroupDirs = Invoke-Command -ComputerName $SourceServer -ScriptBlock $ScriptBlockReadDirectories -ArgumentList $SourceGroupFoldersLocation

write-host "ReadGroupDirs $ReadGroupDirs"

$GroupDirResults = Invoke-Command -ComputerName $NewDFSServer -ScriptBlock $ScriptBlockWriteDirectories -ArgumentList @($GroupDrive, $ReadGroupDirs)

#--------------------SMB Information----------------------------#
#extract the arrays from the smb returns
$GroupSMBSharesReturn = Invoke-Command -ComputerName $SourceServer -Scriptblock $ScriptBlockGetSMBShares -ArgumentList $GroupRootPaths
##$UserSMBSharesReturn = Invoke-Command -ComputerName $SourceServer -Scriptblock $ScriptBlockGetSMBShares -ArgumentList $UserRootPaths

$GroupSMBShares = $GroupSMBSharesReturn[0]
$GroupSMBPathNoShares = $GroupSMBSharesReturn[1]
##$UserSMBShares = $UserSMBSharesReturn[0]
##$UserSMBPathNoShares = $GroupSMBSharesReturn[1]

#--------------------SMB Information----------------------------#
#
#
#--------------------Quota Template Information----------------------------#
#Get the Quota Templates from the Source and Destination servers in order to check which ones need to be written.
$AllSourceServerTemplates = Invoke-Command -ComputerName $SourceServer -Scriptblock $ScriptBlockGetFSRMQuotaTemplates
#$AllDestinationServerTemplates = Invoke-Command -ComputerName $NewDFSServer -Scriptblock $ScriptBlockGetFSRMQuotaTemplates
#$AllDestinationServerTemplatesREP = Invoke-Command -ComputerName $NewDFSServer -Scriptblock $ScriptBlockGetFSRMQuotaTemplates

#--------------------Quota Template Information----------------------------#
#
#
#--------------------FSRM Quota Information----------------------------#

#Obtain the necessary Information from the remote servers
$GroupPathQuotasResult = Invoke-Command -ComputerName $SourceServer -Scriptblock $ScriptBlockGetQuotas -ArgumentList $SGroupRootPaths
##$UserPathQuotasResult = Invoke-Command -ComputerName $SourceServer -Scriptblock $ScriptBlockGetQuotas -ArgumentList $UserRootPaths

$GroupPathQuotas = $GroupPathQuotasResult[0]
$NoGroupPathQuotas = $GroupPathQuotasResult[1]
##$UserPathQuotas = $UserPathQuotasResult[0]
##$NoUserPathQuotas = $UserPathQuotasResult[1]
#Consolidate User and Group Path Quotas
##$AllPathQuotas = $UserPathQuotas + $GroupPathQuotas

#--------------------FSRM Quota Information----------------------------#
#
#
#--------------------ACL Information----------------------------#


write-host "SourceGroupFoldersLocation: $($SourceGroupFoldersLocation)"

#Get the ACL for the TL Drives
$GroupPathACLs = Invoke-Command -ComputerName $SourceServer -Scriptblock $ScriptBlockGetACLInfo -ArgumentList @($SourceGroupFoldersLocation, $ReadGroupDirs)#$GroupDrive
#$GroupDriveACL = Invoke-Command -ComputerName $SourceServer -Scriptblock $ScriptBlockGetACLInfo -ArgumentList @($SourceGroupFoldersLocation, $ReadGroupDirs)#$GroupDrive
#$HomeDriveACL = Invoke-Command -ComputerName $SourceServer -Scriptblock $ScriptBlockGetACLInfo -ArgumentList $UserDrive


#$GroupPathACLs = Invoke-Command -ComputerName $SourceServer -Scriptblock $ScriptBlockGetACLInfo -ArgumentList @($GroupDrive, $ReadGroupDirs) #$SGroupRootPaths

write-host "GroupPathACLs length ist $($GroupPathACLs.Length)"
$GroupPathACLs






#--------------------ACL Information----------------------------#


<#
#Need to extract the name description and size in order to carry out the compare and create the templates on the target. The new objects on the destination server will not be identical but the name is unique.
foreach ($sst in $AllSourceServerTemplates) {
	
	$AllSourceServerTemplatesEdited += $($sst | select-object -property name, Description, size)

}


foreach ($dst in $AllDestinationServerTemplates) {
	
	$AllDestinationServerTemplatesEdited += $($dst | select-object -Property name, Description, size)

	
}

#Sort the Templates that are on the source machine but not the target
$SourceServerTemplatesDifference = Compare-Object -ReferenceObject $AllSourceServerTemplates -DifferenceObject $AllDestinationServerTemplates -PassThru |
               Where-Object { $_ -notin $AllDestinationServerTemplates }
			   


$SourceServerTemplatesNotOnDestination = @()

foreach($sstnd in $SourceServerTemplatesDifference){

	$SourceServerTemplatesNotOnDestination += $($sstnd | select-object -property name, description, size)

}


#write missing templates if any are not available on the target
if($SourceServerTemplatesNotOnDestination.count -gt 0){

	$CreateQuotaTemplatesResult = Invoke-Command -ComputerName $NewDFSServer -Scriptblock $ScriptBlockSetFSRMQuotaTemplates -ArgumentList $SourceServerTemplatesNotOnDestination

}



#Obtain the necessary Information from the remote servers
$GroupPathQuotasResult = Invoke-Command -ComputerName $SourceServer -Scriptblock $ScriptBlockGetQuotas -ArgumentList $SGroupRootPaths
$UserPathQuotasResult = Invoke-Command -ComputerName $SourceServer -Scriptblock $ScriptBlockGetQuotas -ArgumentList $SUserRootPaths
$GroupPathACLsResult = Invoke-Command -ComputerName $SourceServer -Scriptblock $ScriptBlockGetACLInfo -ArgumentList $SGroupRootPaths
$UserPathACLsResult = Invoke-Command -ComputerName $SourceServer -Scriptblock $ScriptBlockGetACLInfo -ArgumentList $SUserRootPaths
#>




#Replace the Folder Name for Group Folders in order to create them on the Replication Server
<#
foreach($dir in $GroupDirsWithSMB){

	$ReplicationFolders += $dir.Replace($GroupSourceFolder, $DFSRFolder)
	#$dir.Replace($GroupSourceFolder, $DFSRFolder)
	#write-host $dir
}
#>
#Write the valid directories to the Replication Server - ONLY Group Folders are needed
#$RepGroupSMBSharesCreate = Invoke-Command -ComputerName $ReplicationServer -Scriptblock $ScriptBlockWriteDirectories -ArgumentList $ReplicationFolders

#$ReplicationFolders





#TODO: Set Quotas on folder
###Invoke-Command -ComputerName $NewDFSServer -Scriptblock $ScriptBlockWriteCreateFolderQuotas -ArgumentList @($GroupDirsWithSMB, $GroupPathQuotas, $AllSourceServerTemplates)

################################Invocation: Get Information from the current Server - END############################


######################Invocation of Setting DFS Information on Servers - START######################

##Double Hash are lines to be uncommented. Commented out for testing - jw 10.06.2026


#--------------------SMB Information----------------------------#

#Write the valid directories to the new Server in the remote location
$NewGroupSMBSharesCreate = Invoke-Command -ComputerName $NewDFSServer -Scriptblock $ScriptBlockWriteDirectories -ArgumentList $GroupDirsWithSMB
##$NewUserSMBSharesCreate = Invoke-Command -ComputerName $NewDFSServer -Scriptblock  $ScriptBlockWriteDirectories -ArgumentList $UserDirsWithSMB

$GroupSMBSharesResult = Invoke-Command -ComputerName $SourceServer -Scriptblock $ScriptBlockSetSMBShares -ArgumentList $GroupSMBShares
##$UserSMBSharesResult = Invoke-Command -ComputerName $SourceServer -Scriptblock $ScriptBlockSetSMBShares -ArgumentList $UserSMBShares

#--------------------SMB Information----------------------------#
#
#
#--------------------Quota Template Information----------------------------#

#Import Templates to new servers
$CreateQuotaTemplatesNewDFSResult = Invoke-Command -ComputerName $NewDFSServer -Scriptblock $ScriptBlockSetFSRMQuotaTemplates -ArgumentList $AllSourceServerTemplates
#$CreateQuotaTemplatesREPResult = Invoke-Command -ComputerName $ReplicationServer -Scriptblock $ScriptBlockSetFSRMQuotaTemplates -ArgumentList $AllSourceServerTemplates
#$CreateQuotaTemplatesResult = Invoke-Command -ComputerName $NewDFSServer -Scriptblock $ScriptBlockSetFSRMQuotaTemplates -ArgumentList 

#--------------------Quota Template Information----------------------------#
#
#
#--------------------FSRM Quota Information----------------------------#

#Set Templates and quotas on target systems
$GroupPathQuotaResult = Invoke-Command -ComputerName $NewDFSServer -Scriptblock $ScriptBlockSetQuotas -ArgumentList $GroupPathQuotas
##$UserPathQuotaResult = Invoke-Command -ComputerName $NewDFSServer -Scriptblock $ScriptBlockSetQuotas -ArgumentList $UserPathQuotas

#--------------------FSRM Quota Information----------------------------#
#
#
#--------------------ACL Information----------------------------#

#Set the NTFS Permissions on the new Server and its Replication Server
#$ScriptBlockWriteCreateFolderACLsResult = Invoke-Command -ComputerName $NewDFSServer -Scriptblock $ScriptBlockWriteCreateFolderACLs -ArgumentList @($GroupDirsWithSMB, $GroupPathACLs)


#$ScriptBlockWriteCreateGroupFolderACLsResult = Invoke-Command -ComputerName $NewDFSServer -Scriptblock $ScriptBlockWriteCreateFolderACLs -ArgumentList $GroupDirResults
#$ScriptBlockWriteCreateGroupFolderACLsResult = Invoke-Command -ComputerName $NewDFSServer -Scriptblock $ScriptBlockWriteCreateFolderACLs -ArgumentList $GroupPathACLs
##$ScriptBlockWriteCreateUserFolderACLsResult = Invoke-Command -ComputerName $NewDFSServer -Scriptblock $ScriptBlockWriteCreateFolderACLs -ArgumentList $UserPathACLs

#write-host "$($GroupPathACLs.length)" -foregroundcolor Red
#write-host "$($GroupRootPaths.Length)" -foregroundcolor Red

write-host "GroupPathACLs $($GroupPathACLs)"


$ScriptBlockSetGroupPathACLInfoResultDFS = Invoke-Command -ComputerName $NewDFSServer -Scriptblock $ScriptBlockSetACLInfo -ArgumentList $GroupPathACLs

#$ScriptBlockSetGroupPathACLInfoResultREP = Invoke-Command -ComputerName $ReplicationServer -Scriptblock $ScriptBlockSetACLInfo -ArgumentList $GroupPathACLs
#$ScriptBlockSetUserPathACLInfoResultDFS = Invoke-Command -ComputerName $NewDFSServer -Scriptblock $ScriptBlockSetACLInfo -ArgumentList $UserPathACLs
#$ScriptBlockSetUserPathACLInfoResultREP = Invoke-Command -ComputerName $ReplicationServer -Scriptblock $ScriptBlockSetACLInfo -ArgumentList $UserPathACLs

#--------------------ACL Information----------------------------#













######################Invocation of Setting DFS Information on Servers - END######################
#
#
######################Print Output of  Variables - START######################


<#
Debug output
$AllSourceServerTemplates
$AllSourceServerTemplates.count
write-host " "
write-host " "
write-host " "
$GroupPathQuotas
$GroupPathQuotas.count
$UserPathQuotas.count
write-host " "
write-host " "
write-host " "
$GroupFolders.count
$UserFolders.count
write-host " "
write-host " "
write-host " "
$NoGroupPathQuotas
$NoUserPathQuotas
#>


#write-host "GroupRootPaths: "
#$GroupRootPaths
#$SourceServerTemplatesNotOnDestination
#$SourceServerTemplatesNotOnDestination.count




#write-host "GroupPathACLs: "
#$GroupPathACLs
#write-host " "
#write-host " "
#write-host " "
#write-host " "
#write-host " "


#write-host "GroupPathACLs Grouped: "
#$GroupPathACLs  |  Group-Object  -Property ShareName

#write-host "userPathACLs: "
#$UserPathACLs

#write-host "ALLPathACLs: "
#$GroupRootPaths
#$UserRootPaths



#write-host "ALL Root Path Quotas: "
#$AllRootPathQuotas



#write-host "Source Templates"
#if($AllSourceServerTemplates){
	
#	$AllSourceServerTemplates
#	write-host "Source Templates Count"
#	$AllSourceServerTemplates.count
#}
#else{
	
#	write-host "no Source templates"
#}

#write-host "Destination Templates"
#if($AllDestinationServerTemplates){
	
#	$AllDestinationServerTemplates
#	write-host "Destination Templates Count"
#	$AllDestinationServerTemplates.count
#}
#else{
	
#	write-host "no Destination templates"
#}





#write-host "Counts for comparison: "
#write-host ""
#write-host "AllRootPathQuotas"
#$AllRootPathQuotas.count
#write-host ""

#write-host "UserRootPaths"
#$UserRootPaths.count
#write-host ""

#write-host "GroupRootPaths"
#$GroupRootPaths.count
#write-host ""

#write-host "SourceServerTemplatesNotOnDestination"
#$SourceServerTemplatesNotOnDestination.count
#write-host ""

#write-host "$ScriptBlockWriteCreateFolderACLsResult paths"
#$ScriptBlockWriteCreateFolderACLsResult[0]
#$GroupDirsWithSMB
#write-host "$ScriptBlockWriteCreateFolderACLsResult acls"
#$ScriptBlockWriteCreateFolderACLsResult[1]

#write-host "UserPathACLs"
#$UserPathACLs
#$UserPathACLs.count

#write-host "GroupPathACLs"
#$GroupPathACLs
#$GroupPathACLs.count



#write-host "$GroupRootPaths"
#$GroupRootPaths
#$GroupRootPaths.count

#write-host "Source server Templates"
#$AllSourceServerTemplates



######################Print Output of  Variables - END#################




