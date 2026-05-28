#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Setup Proxmox VE for Crucible on Windows with Hyper-V
.DESCRIPTION
    Creates Proxmox VM in Hyper-V and configures Windows port forwarding for Keycloak OIDC
.PARAMETER VMName
    Name of the Hyper-V VM (default: proxmox-ve)
.PARAMETER VMPath
    Path for VM files (default: %USERPROFILE%\Hyper-V\Virtual Machines)
.PARAMETER Memory
    VM memory in GB (default: 8GB)
.PARAMETER ProcessorCount
    Number of virtual CPUs (default: 4)
.PARAMETER DiskSize
    Virtual disk size in GB (default: 100GB)
.PARAMETER SwitchName
    Hyper-V network switch (default: Default Switch)
.PARAMETER ProxmoxISO
    Path to Proxmox ISO file (default: auto-detect in repo root)
.PARAMETER SkipVMCreation
    Skip VM creation, only setup port forwarding
.EXAMPLE
    .\scripts\setup-proxmox-windows.ps1
.EXAMPLE
    .\scripts\setup-proxmox-windows.ps1 -SkipVMCreation
#>

param(
    [string]$VMName = "proxmox-ve",
    [string]$VMPath = "$env:USERPROFILE\Hyper-V\Virtual Machines",
    [int]$Memory = 8,
    [int]$ProcessorCount = 4,
    [int]$DiskSize = 100,
    [string]$SwitchName = "Default Switch",
    [string]$ProxmoxISO = "",
    [switch]$SkipVMCreation
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Proxmox VE Setup for Crucible (Windows)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Convert GB to bytes
$MemoryBytes = [int64]$Memory * 1GB
$DiskSizeBytes = [int64]$DiskSize * 1GB

#region Port Forwarding Setup
function Setup-PortForwarding {
    Write-Host "Configuring Keycloak port forwarding..." -ForegroundColor Cyan
    Write-Host ""

    # Get the switch adapter IP
    $switchAdapter = Get-NetIPAddress -InterfaceAlias "vEthernet ($SwitchName)" -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if (-not $switchAdapter) {
        Write-Host "Warning: Could not detect switch IP address" -ForegroundColor Yellow
        Write-Host "Port forwarding will be skipped" -ForegroundColor Yellow
        return
    }

    $keycloakHost = $switchAdapter.IPAddress
    Write-Host "  Switch IP: $keycloakHost" -ForegroundColor Gray

    # Remove existing rules
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

    Write-Host ""
    Write-Host "Port forwarding configured!" -ForegroundColor Green
    Write-Host "  Proxmox can access Keycloak at: http://${keycloakHost}:8080" -ForegroundColor Green
    Write-Host ""
}
#endregion

#region VM Creation
function Create-ProxmoxVM {
    Write-Host "Creating Proxmox VE VM in Hyper-V..." -ForegroundColor Cyan
    Write-Host "  VM Name: $VMName"
    Write-Host "  VM Path: $VMPath"
    Write-Host "  Memory: ${Memory}GB"
    Write-Host "  Processors: $ProcessorCount"
    Write-Host "  Disk Size: ${DiskSize}GB"
    Write-Host "  Network Switch: $SwitchName"
    Write-Host ""

    # Check if Hyper-V is available
    if (-not (Get-Command Get-VM -ErrorAction SilentlyContinue)) {
        Write-Host "Error: Hyper-V PowerShell module not found" -ForegroundColor Red
        Write-Host "Enable Hyper-V from Windows Features or run on a Hyper-V host"
        exit 1
    }

    # Determine ISO path
    if ([string]::IsNullOrEmpty($ProxmoxISO)) {
        $repoRoot = Split-Path $PSScriptRoot -Parent
        $ProxmoxISO = Get-ChildItem -Path $repoRoot -Filter "proxmox-ve_*.iso" | Select-Object -First 1 -ExpandProperty FullName

        if ([string]::IsNullOrEmpty($ProxmoxISO)) {
            Write-Host "Error: Proxmox ISO not found in repo root" -ForegroundColor Red
            Write-Host ""
            Write-Host "Download from: https://www.proxmox.com/en/downloads" -ForegroundColor Yellow
            Write-Host "Place ISO in repo root or specify with -ProxmoxISO parameter"
            Write-Host ""
            Write-Host "Example:" -ForegroundColor Cyan
            Write-Host "  .\scripts\setup-proxmox-windows.ps1 -ProxmoxISO 'C:\path\to\proxmox-ve_9.1-1.iso'"
            exit 1
        }
    }

    if (-not (Test-Path $ProxmoxISO)) {
        Write-Host "Error: ISO not found: $ProxmoxISO" -ForegroundColor Red
        exit 1
    }

    Write-Host "Using ISO: $ProxmoxISO" -ForegroundColor Green
    Write-Host ""

    # Check if VM already exists
    $existingVM = Get-VM -Name $VMName -ErrorAction SilentlyContinue
    if ($existingVM) {
        Write-Host "VM '$VMName' already exists" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "If you need to recreate it:" -ForegroundColor Cyan
        Write-Host "  Stop-VM -Name '$VMName' -TurnOff -Force"
        Write-Host "  Remove-VM -Name '$VMName' -Force"
        Write-Host "  Remove-Item -Path '$VMPath\$VMName' -Recurse -Force"
        Write-Host ""
        Write-Host "Skipping VM creation, continuing with port forwarding..." -ForegroundColor Yellow
        Write-Host ""
        return
    }

    # Check if network switch exists
    $switch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
    if (-not $switch) {
        Write-Host "Error: Network switch '$SwitchName' not found" -ForegroundColor Red
        Write-Host ""
        Write-Host "Available switches:"
        Get-VMSwitch | Format-Table Name, SwitchType -AutoSize
        Write-Host ""
        Write-Host "Specify a switch with -SwitchName parameter"
        exit 1
    }

    # Detect gateway and subnet for the switch
    $switchAdapter = Get-NetIPAddress -InterfaceAlias "vEthernet ($SwitchName)" -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if ($switchAdapter) {
        $gateway = $switchAdapter.IPAddress
        $prefixLength = $switchAdapter.PrefixLength
        Write-Host "Network configuration for '$SwitchName':" -ForegroundColor Yellow
        Write-Host "  Gateway: $gateway"
        Write-Host "  Subnet: /$prefixLength"
        Write-Host "  Use these values during Proxmox installation"
        Write-Host ""
    }

    # Create VM directory
    $vmDir = Join-Path $VMPath $VMName
    if (Test-Path $vmDir) {
        Write-Host "Warning: VM directory already exists: $vmDir" -ForegroundColor Yellow
        $response = Read-Host "Delete and continue? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-Host "Cancelled" -ForegroundColor Yellow
            exit 1
        }
        Remove-Item -Path $vmDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $vmDir | Out-Null

    # Create the VM
    Write-Host "Creating VM..." -ForegroundColor Cyan
    $vm = New-VM -Name $VMName `
        -Path $VMPath `
        -MemoryStartupBytes $MemoryBytes `
        -Generation 2 `
        -SwitchName $SwitchName

    # Configure VM
    Write-Host "Configuring VM..." -ForegroundColor Cyan
    Set-VMProcessor -VM $vm -Count $ProcessorCount
    Set-VMProcessor -VM $vm -ExposeVirtualizationExtensions $true  # Nested virtualization
    Set-VMMemory -VM $vm -DynamicMemoryEnabled $false
    Set-VMFirmware -VM $vm -EnableSecureBoot Off
    Set-VM -VM $vm -CheckpointType Disabled

    # Create virtual hard disk
    Write-Host "Creating virtual disk..." -ForegroundColor Cyan
    $vhdPath = Join-Path $vmDir "$VMName.vhdx"
    New-VHD -Path $vhdPath -SizeBytes $DiskSizeBytes -Dynamic | Out-Null
    Add-VMHardDiskDrive -VM $vm -Path $vhdPath

    # Add DVD drive and mount ISO
    Write-Host "Mounting Proxmox ISO..." -ForegroundColor Cyan
    Add-VMDvdDrive -VM $vm -Path $ProxmoxISO

    # Set boot order (DVD first, then HD)
    $dvd = Get-VMDvdDrive -VM $vm
    $hd = Get-VMHardDiskDrive -VM $vm
    Set-VMFirmware -VM $vm -BootOrder $dvd, $hd

    Write-Host ""
    Write-Host "VM created successfully!" -ForegroundColor Green
    Write-Host ""

    # Start VM
    Write-Host "Starting VM..." -ForegroundColor Cyan
    Start-VM -VM $vm

    Write-Host ""
    Write-Host "VM started!" -ForegroundColor Green
    Write-Host ""
}
#endregion

#region Main
try {
    # Create VM if not skipped
    if (-not $SkipVMCreation) {
        Create-ProxmoxVM
    }

    # Always setup port forwarding
    Setup-PortForwarding

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "Setup Complete!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""

    if (-not $SkipVMCreation) {
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "1. Connect to VM console:" -ForegroundColor Cyan
        Write-Host "   vmconnect.exe localhost '$VMName'"
        Write-Host ""
        Write-Host "2. Follow Proxmox installation wizard:" -ForegroundColor Cyan
        Write-Host "   - Accept EULA"
        Write-Host "   - Select target disk"
        Write-Host "   - Set timezone/keyboard"
        Write-Host "   - Set root password"
        Write-Host "   - Network: ACCEPT DHCP (note the IP address)"
        Write-Host "   - Hostname: proxmox-ve.local"
        Write-Host ""
        Write-Host "3. After installation, configure static IP:" -ForegroundColor Cyan
        Write-Host "   - Login to console as root"
        Write-Host "   - Edit: nano /etc/network/interfaces"
        Write-Host "   - Change 'dhcp' to 'static' and add:"
        Write-Host "     address <DHCP_IP>/20"
        Write-Host "     gateway <DHCP_GATEWAY>"
        Write-Host "   - Save and run: systemctl restart networking"
        Write-Host ""
        Write-Host "4. Run the Proxmox setup script from WSL/dev container:" -ForegroundColor Cyan
        Write-Host "   export PROXMOX_HOST='<PROXMOX_IP>'"
        Write-Host "   ./scripts/crucible-proxmox.sh setup"
        Write-Host ""
        Write-Host "Opening VM console..." -ForegroundColor Cyan
        Start-Process vmconnect.exe -ArgumentList localhost,$VMName
    } else {
        Write-Host "Port forwarding configured for existing Proxmox VM" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To complete Proxmox setup, run from WSL/dev container:" -ForegroundColor Cyan
        Write-Host "  export PROXMOX_HOST='<PROXMOX_IP>'"
        Write-Host "  ./scripts/crucible-proxmox.sh setup"
    }

    Write-Host ""
    Write-Host "Active port proxy rules:" -ForegroundColor Cyan
    netsh interface portproxy show v4tov4
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
#endregion
