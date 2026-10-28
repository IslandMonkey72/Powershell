# Get all servers running Windows Server 2012
$servers = Get-ADComputer -Filter {OperatingSystem -like "*Windows Server 2012*"} -Property OperatingSystem

foreach ($server in $servers) {
    # Check if Hyper-V role is installed
    $hyperVRole = Invoke-Command -ComputerName $server.Name -ScriptBlock {
        Get-WindowsFeature -Name Hyper-V
    }

    if ($hyperVRole.Installed) {
        Write-Host "$($server.Name) has Hyper-V role installed."
    } else {
        Write-Host "$($server.Name) does not have Hyper-V role installed."
    }
}