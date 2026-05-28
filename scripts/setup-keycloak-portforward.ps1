#Requires -RunAsAdministrator

param(
    [string]$SwitchName = "Default Switch"
)

Write-Host "Configuring Keycloak port forwarding for Proxmox OIDC..." -ForegroundColor Cyan
Write-Host ""

# Get the switch adapter IP
$switchAdapter = Get-NetIPAddress -InterfaceAlias "vEthernet ($SwitchName)" -AddressFamily IPv4 -ErrorAction SilentlyContinue
$keycloakHost = $switchAdapter.IPAddress

if ([string]::IsNullOrEmpty($keycloakHost)) {
    Write-Host "Error: Could not detect switch IP address" -ForegroundColor Red
    exit 1
}

Write-Host "Configuring port forwarding from $keycloakHost to localhost..." -ForegroundColor Yellow

# Check and remove existing rules
$existing8443 = netsh interface portproxy show v4tov4 | Select-String "8443.*127.0.0.1"
$existing8080 = netsh interface portproxy show v4tov4 | Select-String "8080.*127.0.0.1"

if ($existing8443) {
    Write-Host "  Removing existing 8443 port proxy..." -ForegroundColor Gray
    netsh interface portproxy delete v4tov4 listenaddress=$keycloakHost listenport=8443 | Out-Null
}
if ($existing8080) {
    Write-Host "  Removing existing 8080 port proxy..." -ForegroundColor Gray
    netsh interface portproxy delete v4tov4 listenaddress=$keycloakHost listenport=8080 | Out-Null
}

# Add port forwarding rules
Write-Host "  Adding port proxy: ${keycloakHost}:8443 -> 127.0.0.1:8443" -ForegroundColor Gray
netsh interface portproxy add v4tov4 listenaddress=$keycloakHost listenport=8443 connectaddress=127.0.0.1 connectport=8443 | Out-Null

Write-Host "  Adding port proxy: ${keycloakHost}:8080 -> 127.0.0.1:8080" -ForegroundColor Gray
netsh interface portproxy add v4tov4 listenaddress=$keycloakHost listenport=8080 connectaddress=127.0.0.1 connectport=8080 | Out-Null

# Firewall rules
Write-Host "  Configuring firewall rules..." -ForegroundColor Gray

$fwRule8443 = Get-NetFirewallRule -DisplayName "Keycloak HTTPS" -ErrorAction SilentlyContinue
$fwRule8080 = Get-NetFirewallRule -DisplayName "Keycloak HTTP" -ErrorAction SilentlyContinue

if ($fwRule8443) {
    Remove-NetFirewallRule -DisplayName "Keycloak HTTPS" | Out-Null
}
if ($fwRule8080) {
    Remove-NetFirewallRule -DisplayName "Keycloak HTTP" | Out-Null
}

New-NetFirewallRule -DisplayName "Keycloak HTTPS" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8443 | Out-Null
New-NetFirewallRule -DisplayName "Keycloak HTTP" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8080 | Out-Null

# Hosts file
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$hostsContent = Get-Content $hostsPath -Raw

if ($hostsContent -notmatch "\bkeycloak\b") {
    Write-Host "  Adding keycloak entry to hosts file..." -ForegroundColor Gray
    Add-Content -Path $hostsPath -Value "`n$keycloakHost keycloak"
    Write-Host "  Added: $keycloakHost keycloak" -ForegroundColor Green
} else {
    Write-Host "  keycloak already in hosts file" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Configuration complete!" -ForegroundColor Green
Write-Host "  Proxmox can access Keycloak at: http://${keycloakHost}:8080" -ForegroundColor Green
Write-Host ""
Write-Host "Active port proxy rules:" -ForegroundColor Cyan
netsh interface portproxy show v4tov4
