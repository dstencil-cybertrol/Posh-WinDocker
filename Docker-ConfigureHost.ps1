Write-Host "Opening Docker Swarm ports in the firewall on Manager Node ($managerNodeIP)..."
$allowedPorts = @(
    "2377",  # Swarm management port
    "7946",  # Swarm communication among nodes
    "4789"   # Overlay network traffic
)
foreach ($port in $allowedPorts) {
    $firewallRuleName = "DockerSwarmPort_$port"
    netsh advfirewall firewall add rule name=$firewallRuleName dir=in action=allow protocol=TCP localport=$port
    Invoke-Command -ComputerName $managerNodeIP -ScriptBlock $firewallRuleScriptBlock
}
Write-Host "Docker Swarm ports opened in the firewall on Manager Node."
