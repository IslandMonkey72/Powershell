# Define the Hyper-V server
$HyperVServer = "DE-INF-70-P"

# Connect to the Hyper-V server
$session = New-PSSession -ComputerName $HyperVServer

# Get the list of roles
$roles = Invoke-Command -Session $session -ScriptBlock {
    Get-ClusterGroup | Select-Object Name, @{Name="OperatingSystem";Expression={(Get-VM -Name $_.Name).GuestOS}}
}

# Display the roles and their operating systems
$roles | Format-Table -AutoSize

# Close the session
Remove-PSSession -Session $session