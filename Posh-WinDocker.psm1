function Configure-DockerHost {
    param (
        [string]$managerNodeIP,
        [string[]]$workerNodeIPs
    )
    
    # Check if Hyper-V feature is enabled
    $hyperVEnabled = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All | Select-Object -ExpandProperty State
    if ($hyperVEnabled -eq "Enabled") {
        Write-Host "Hyper-V is already enabled on Manager Node ($managerNodeIP)."
    } else {
        Write-Host "Enabling Hyper-V feature on Manager Node ($managerNodeIP)..."
        try {
            Invoke-Command -ComputerName $managerNodeIP -ScriptBlock {
                Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
            }
            Write-Host "Hyper-V enabled on Manager Node."
        } catch {
            Write-Host "Failed to enable Hyper-V on Manager Node. Error: $_"
        }
    }

    # Check if Windows Containers feature is enabled
    $containersEnabled = Get-WindowsOptionalFeature -Online -FeatureName Containers -All | Select-Object -ExpandProperty State
    if ($containersEnabled -eq "Enabled") {
        Write-Host "Windows Containers feature is already enabled on Manager Node ($managerNodeIP)."
    } else {
        Write-Host "Enabling Windows Containers feature on Manager Node ($managerNodeIP)..."
        try {
            Invoke-Command -ComputerName $managerNodeIP -ScriptBlock {
                Enable-WindowsOptionalFeature -Online -FeatureName Containers
            }
            Write-Host "Windows Containers enabled on Manager Node."
        } catch {
            Write-Host "Failed to enable Windows Containers on Manager Node. Error: $_"
        }
    }
    Write-Host "Windows Containers installed on Manager Node."

    # Open required Docker Swarm ports in the firewall
    Write-Host "Opening Docker Swarm ports in the firewall on Manager Node ($managerNodeIP)..."
    $allowedPorts = @(
        "2377",  # Swarm management port
        "7946",  # Swarm communication among nodes
        "4789"   # Overlay network traffic
    )
    foreach ($port in $allowedPorts) {
        $firewallRuleName = "DockerSwarmPort_$port"
        Invoke-Command -ComputerName $managerNodeIP -ScriptBlock {netsh advfirewall firewall add rule name='$firewallRuleName' dir=in action=allow protocol=TCP localport=$port}
    }
    Write-Host "Docker Swarm ports opened in the firewall on Manager Node."

    # Enable IPv4 pings
    Write-Host "Enabling IPv4 pings on Manager Node ($managerNodeIP)..."
    $icmpRuleScriptBlock = New-NetFirewallRule -DisplayName 'Allow ICMPv4-In' -Protocol ICMPv4
    Invoke-Command -ComputerName $managerNodeIP -ScriptBlock $icmpRuleScriptBlock
    Write-Host "IPv4 pings enabled on Manager Node."

    Write-Host "Docker Swarm environment configuration completed on Manager Node."

    # Repeat the above steps for each worker node
    foreach ($workerNodeIP in $workerNodeIPs) {
        # Install Hyper-V feature
        Write-Host "Installing Hyper-V feature on Manager Node ($workerNodeNodeIP)..."
        Invoke-Command -ComputerName $workerNodeIP -ScriptBlock {
            Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
        }
        Write-Host "Hyper-V installed on Manager Node."

        # Install Windows Containers feature
        Write-Host "Installing Windows Containers feature on Manager Node ($workerNodeIP)..."
        Invoke-Command -ComputerName $workerNodeIP -ScriptBlock {
            Enable-WindowsOptionalFeature -Online -FeatureName Containers
        }
        Write-Host "Windows Containers installed on Manager Node."

        # Open required Docker Swarm ports in the firewall
        Write-Host "Opening Docker Swarm ports in the firewall on Manager Node ($workerNodeIP)..."
        $allowedPorts = @(
            "2377",  # Swarm management port
            "7946",  # Swarm communication among nodes
            "4789"   # Overlay network traffic
        )
        foreach ($port in $allowedPorts) {
            $firewallRuleName = "DockerSwarmPort_$port"
            Invoke-Command -ComputerName $workerNodeIP -ScriptBlock {netsh advfirewall firewall add rule name='$firewallRuleName' dir=in action=allow protocol=TCP localport=$port}
        }
        Write-Host "Docker Swarm ports opened in the firewall on Manager Node."

        # Enable IPv4 pings
        Write-Host "Enabling IPv4 pings on Manager Node ($workerNodeIP)..."
        $icmpRuleScriptBlock = New-NetFirewallRule -DisplayName 'Allow ICMPv4-In' -Protocol ICMPv4
        Invoke-Command -ComputerName $workerNodeIP -ScriptBlock $icmpRuleScriptBlock
        Write-Host "IPv4 pings enabled on Manager Node."

        Write-Host "Docker Swarm environment configuration completed on Manager Node."
      
    }
}

Export-ModuleMember -Function Configure-DockerHost

function Install-Docker {
    	<#
	    .SYNOPSIS
	    Installs Docker from Binaries into an Air Gapped Windows Server environment.
	    .DESCRIPTION
	    The function uses the Get-Item command to return the information for a provided registry key.
	    .PARAMETER Path
	    The path that will be searched for a registry key.
	    .EXAMPLE
	    Docker-Install -Path C:\
	    .INPUTS
	    System.String
	    
	    .NOTES
	    example
	    .LINK
	    https://github.com/cybertrol-engineering/CE.Deployments.Templates/blob/main/windows/Install-Docker.ps1
	#>
    param(
        [Parameter(Mandatory= $true)]
        [string]$Path
    )

    
    Write-Host "Unzipping Docker Binaries"
    Expand-Archive -Path $dockerBinariesPath -DestinationPath $Env:ProgramFiles -Force
    
    Write-Host "Registering Docker Engine Service"
    & $Env:ProgramFiles\Docker\dockerd --register-service
    
    Write-Host "Starting Docker Service"
    Start-Service docker
    
    Write-Host "Adding Docker commandline to SYSTEM Path"
    # Add Docker path to SYSTEM Path to use in the command line
    $directoryToAdd = "$Env:ProgramFiles\Docker\"
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::Machine)
    $newPath = "$currentPath;$directoryToAdd"
    [Environment]::SetEnvironmentVariable("PATH", $newPath, [System.EnvironmentVariableTarget]::Machine)
    
    Write-Host "Docker Install Finished. Please Restart Computer."
}

Export-ModuleMember -Function Install-Docker

function Docker-Load {
    <#
    .SYNOPSIS
    Installs Docker from Binaries into an Air Gapped Windows Server environment.
    .DESCRIPTION
    The function uses the Get-Item command to return the information for a provided registry key.
    .PARAMETER Path
    The path that will be searched for a registry key.
    .EXAMPLE
    Docker-Load -Path C:\images
    .INPUTS
    System.String
    
    .NOTES
    example
    .LINK
    https://github.com/cybertrol-engineering/CE.Deployments.Templates/blob/main/windows/Docker-Load.ps1
#>
    param(
        [Parameter(Mandatory= $true)]
        [string]$Path
    )
    # Get a list of .tar files in the folder
    $tarFiles = Get-ChildItem -Path $Path -Filter "*.tar"

    # Loop through each .tar file and load it using docker load
    foreach ($tarFile in $tarFiles) {
        $loadCommand = "docker load --input $($tarFile.FullName)"
        Invoke-Expression $loadCommand
    }
    }
Export-ModuleMember -Function Docker-Load

function Init-Swarm {
    <#
    .SYNOPSIS
    Installs Docker from Binaries into an Air Gapped Windows Server environment.
    .DESCRIPTION
    The function uses the Get-Item command to return the information for a provided registry key.
    .PARAMETER managerNodeIP
    The path that will be searched for a registry key.
    .EXAMPLE
    Docker-Load -Path C:\images
    .INPUTS
    System.String
    
    .NOTES
    example
    .LINK
    https://github.com/cybertrol-engineering/CE.Deployments.Templates/blob/main/windows/Docker-Load.ps1
#>
    param(
        [Parameter(Mandatory= $true)]
        [string]$managerNodeIP,
        [string[]]$workerNodeIPs
    )

        Write-Host "Initializing Docker Swarm on Manager Node ($managerNodeIP)"
        
        $initCommand = "docker swarm init --advertise-addr $managerNodeIP"
        $swarmInitResult = Invoke-Expression $initCommand

        # Extract the join token for worker nodes
        $joinToken = ($swarmInitResult | Select-String "docker swarm join --token" | ForEach-Object { $_.ToString() -match 'docker swarm join --token (.+)' | Out-Null; $Matches[1] })

        Write-Host "Joining Worker Nodes to the Swarm:"

        # Join the worker nodes to the Swarm
        foreach ($workerNodeIP in $workerNodeIPs) {
            Write-Host "Joining Worker Node ($workerNodeIP)"
            $joinWorkerCommand = "docker swarm join --token $joinToken $managerNodeIP:2377"
            Invoke-Expression $joinWorkerCommand
        }

        Write-Host "Docker Swarm Initialization and Worker Node Join Completed."
    }
Export-ModuleMember -Function Init-Swarm
