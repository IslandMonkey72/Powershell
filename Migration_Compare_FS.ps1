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
$SourceServer = $ServerABBR + "-INF-002"
$DFSRFolder = "DFSR-" + $ServerABBR 
$QuotaTemplates = @()

#Group Share Variables
$GroupRootPaths = @()
$ReplicationFolders = @()
$GroupDrive = 'G:'
$GroupSourceFolder = "Gruppen" + $ServerABBR


$SourceGroupFoldersLocation = $GroupDrive + $GroupSourceFolder


#User Share Variables
$UserRootPaths = @()
$UserDrive = 'H:\'
$UserSourceFolder = "Home" + $ServerABBR




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

$ScriptBlockReadDirectories = {
	
	$DirNames = @()
	
	
	
	if($args.Length -gt 1){
		
		Write-host "There are too many paths to read from on the source Server"
		Exit 1
	}
	
	
	$root = $args[0]
	
	if(-not (Test-Path $root)){
	
		write-host "The Path $($args) does not exist on the server Please check and try again"
		Exit 1
	}
	
	$root = $args[0]
	
	#write-host "ScriptBlockReadDirectories args $($args)"
	
	$dirs = get-childitem $args
	
	foreach($dir in $dirs){
		$DirNames += ($root + "\" + $dir.name)
		
	}
	
	return $DirNames
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



################################Get and Set SMB Shares - End############################
#
#
################################Get and Set NTFS Permissions (ACL) - Start############################

#Return the ACLs for the top level folders on the remote server
$ScriptBlockGetACLInfo = {
	
	$ACLs = @()
	
	write-host "args Length $($args.length)"
	write-host "args  $($args)"	
	
	foreach($path in $args){
		
		$acl = get-acl -path $path
	
		$ACLs += $acl
		write-host "ACLs has had an acl assigned" -foregroundcolor Blue
		write-host "Length of Accesss is $($acl.access.count) has had an acl assigned" -foregroundcolor Yellow
	}
	
	write-host "GetACL: ACLs Length in Get Function is: $($ACLs.length)" -foregroundcolor Green
	
	return $ACLs
}

	

################################Get and Set NTFS Permissions (ACL) - END############################
#
#
################################Remote ScriptBlock Code END############################
#
#
################################Invocation: Get Information from the current Server - START############################



$ReadSGroupDirs = Invoke-Command -ComputerName $SourceServer -ScriptBlock $ScriptBlockReadDirectories -ArgumentList $SourceGroupFoldersLocation
$ReadTGroupDirs = Invoke-Command -ComputerName $NewDFSServer -ScriptBlock $ScriptBlockReadDirectories -ArgumentList $GroupDrive


#write-host "ReadSGroupDirs: $ReadSGroupDirs"

#write-host "ReadTGroupDirs $ReadTGroupDirs"


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
$AllTargetServerTemplates = Invoke-Command -ComputerName $NewDFSServer -Scriptblock $ScriptBlockGetFSRMQuotaTemplates
#$AllDestinationServerTemplates = Invoke-Command -ComputerName $NewDFSServer -Scriptblock $ScriptBlockGetFSRMQuotaTemplates
#$AllDestinationServerTemplatesREP = Invoke-Command -ComputerName $NewDFSServer -Scriptblock $ScriptBlockGetFSRMQuotaTemplates

#--------------------Quota Template Information----------------------------#
#
#
#--------------------FSRM Quota Information----------------------------#

#Obtain the necessary Information from the remote servers
$SourceGroupPathQuotasResult = Invoke-Command -ComputerName $SourceServer -Scriptblock $ScriptBlockGetQuotas -ArgumentList $SGroupRootPaths
$TargetGroupPathQuotasResult = Invoke-Command -ComputerName $NewDFSServer -Scriptblock $ScriptBlockGetQuotas -ArgumentList $SGroupRootPaths
##$UserPathQuotasResult = Invoke-Command -ComputerName $SourceServer -Scriptblock $ScriptBlockGetQuotas -ArgumentList $UserRootPaths

##
##$GroupPathQuotas = $GroupPathQuotasResult[0]
##$NoGroupPathQuotas = $GroupPathQuotasResult[1]
##$UserPathQuotas = $UserPathQuotasResult[0]
##$NoUserPathQuotas = $UserPathQuotasResult[1]
#Consolidate User and Group Path Quotas
##$AllPathQuotas = $UserPathQuotas + $GroupPathQuotas

#--------------------FSRM Quota Information----------------------------#
#
#
#--------------------ACL Information----------------------------#


#Get the ACL for the TL Drives
$SourceGroupDriveACL = Invoke-Command -ComputerName $SourceServer -Scriptblock $ScriptBlockGetACLInfo -ArgumentList $GroupDrive
$TargetGroupDriveACL = Invoke-Command -ComputerName $NewDFSServer -Scriptblock $ScriptBlockGetACLInfo -ArgumentList $GroupDrive
#$HomeDriveACL = Invoke-Command -ComputerName $SourceServer -Scriptblock $ScriptBlockGetACLInfo -ArgumentList $UserDrive

$SourceGroupPathACLsResult = Invoke-Command -ComputerName $SourceServer -Scriptblock $ScriptBlockGetACLInfo -ArgumentList $ReadSGroupDirs
$TargetGroupPathACLsResult = Invoke-Command -ComputerName $NewDFSServer -Scriptblock $ScriptBlockGetACLInfo -ArgumentList $ReadTGroupDirs
#$UserPathACLsResult = Invoke-Command -ComputerName $SourceServer -Scriptblock $ScriptBlockGetACLInfo -ArgumentList $SUserRootPaths

#$GroupPathACLs = Invoke-Command -ComputerName $SourceServer -Scriptblock $ScriptBlockGetACLInfo -ArgumentList @($GroupDrive, $ReadGroupDirs) #$SGroupRootPaths

write-host "GroupPathACLs length ist $($GroupPathACLs.Length)"
$GroupDriveACL




#Qualify the results
#$GroupPathACLs = $GroupPathACLsResult[0]
#$NoGroupPathACLs = $GroupPathACLsResult[1]
#$UserPathACLs = $UserPathACLsResult[0]
#$NoUserPathACLs = $UserPathACLsResult[1]


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










#Filter Home and user Shares for directories that do not have a share - only those with an SMB Share will be created on the new server.
##$tmpGroupDirsWithSMB = Compare-object -ReferenceObject $GroupRootPaths -DifferenceObject $NoGroupSMBShares
##$tmpUserDirsWithSMB = Compare-object -ReferenceObject $UserRootPaths -DifferenceObject $NoUserSMBShares

##$GroupDirsWithSMB = $tmpGroupDirsWithSMB.InputObject
#$GroupDirsWithSMB

##$UserDirsWithSMB = $tmpUserDirsWithSMB.InputObject
#$UserDirsWithSMB


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




