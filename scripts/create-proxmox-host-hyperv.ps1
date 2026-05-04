# Create Proxmox VE host VM in Hyper-V
# This script must run on Windows with Hyper-V installed with Administrator privileges

#Requires -RunAsAdministrator

param(
    [string]$VMName = "proxmox-ve",
    [string]$VMPath = "$env:USERPROFILE\Hyper-V\Virtual Machines",
    [int64]$Memory = 8GB,
    [int]$ProcessorCount = 4,
    [int64]$DiskSize = 100GB,
    [string]$ProxmoxVersion = "9.1-1",
    [string]$ProxmoxISO = "",
    [string]$ProxmoxDownloadURL = "https://enterprise.proxmox.com/iso/proxmox-ve_9.1-1.iso",
    [string]$SwitchName = "Default Switch",
    [string]$StaticIP = "172.22.69.122"
)

Write-Host "Creating Proxmox VE VM in Hyper-V" -ForegroundColor Cyan
Write-Host "  VM Name: $VMName"
Write-Host "  VM Path: $VMPath"
Write-Host "  Memory: $($Memory / 1GB)GB"
Write-Host "  Processors: $ProcessorCount"
Write-Host "  Disk Size: $($DiskSize / 1GB)GB"
Write-Host "  Network Switch: $SwitchName"
Write-Host "  Static IP: $StaticIP (configure during installation)"
Write-Host ""

# Check if Hyper-V is available
if (-not (Get-Command Get-VM -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Hyper-V PowerShell module not found" -ForegroundColor Red
    Write-Host "Enable Hyper-V from Windows Features or run on a Hyper-V host"
    exit 1
}

# Determine ISO path
if ([string]::IsNullOrEmpty($ProxmoxISO)) {
    $ProxmoxISO = Join-Path (Split-Path $PSScriptRoot -Parent) "proxmox-ve_$ProxmoxVersion.iso"
}

# Download ISO if not present
if (-not (Test-Path $ProxmoxISO)) {
    Write-Host "Proxmox ISO not found at: $ProxmoxISO" -ForegroundColor Yellow
    Write-Host "Downloading from: $ProxmoxDownloadURL" -ForegroundColor Yellow
    Write-Host ""

    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $ProxmoxDownloadURL -OutFile $ProxmoxISO -UseBasicParsing
        Write-Host "Downloaded Proxmox ISO: $ProxmoxISO" -ForegroundColor Green
    }
    catch {
        Write-Host "Error downloading ISO: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Download manually from:"
        Write-Host "  https://www.proxmox.com/en/downloads/proxmox-virtual-environment/iso"
        Write-Host ""
        Write-Host "Then run:"
        Write-Host "  .\scripts\create-proxmox-host-hyperv.ps1 -ProxmoxISO 'C:\path\to\proxmox-ve_$ProxmoxVersion.iso'"
        exit 1
    }
}

Write-Host "Using ISO: $ProxmoxISO" -ForegroundColor Green
Write-Host ""

# Check if VM already exists
$existingVM = Get-VM -Name $VMName -ErrorAction SilentlyContinue
if ($existingVM) {
    Write-Host "Error: VM '$VMName' already exists" -ForegroundColor Red
    Write-Host "Delete it or choose a different name with -VMName parameter"
    exit 1
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
    Write-Host "Detected network configuration for '$SwitchName':" -ForegroundColor Yellow
    Write-Host "  Gateway: $gateway"
    Write-Host "  Subnet: /$prefixLength"
    Write-Host "  Use these values during Proxmox installation"
    Write-Host ""
}

# Create VM directory
$vmDir = Join-Path $VMPath $VMName
New-Item -ItemType Directory -Force -Path $vmDir | Out-Null

# Create the VM
Write-Host "Creating VM..." -ForegroundColor Cyan
$vm = New-VM -Name $VMName `
    -Path $VMPath `
    -MemoryStartupBytes $Memory `
    -Generation 2 `
    -SwitchName $SwitchName

# Set processor count
Set-VMProcessor -VM $vm -Count $ProcessorCount

# Enable nested virtualization (REQUIRED for Proxmox)
Write-Host "Enabling nested virtualization..." -ForegroundColor Cyan
Set-VMProcessor -VM $vm -ExposeVirtualizationExtensions $true

# Disable dynamic memory (Proxmox needs static memory)
Set-VMMemory -VM $vm -DynamicMemoryEnabled $false

# Disable Secure Boot (Linux compatibility)
Set-VMFirmware -VM $vm -EnableSecureBoot Off

# Create virtual hard disk
Write-Host "Creating virtual disk..." -ForegroundColor Cyan
$vhdPath = Join-Path $vmDir "$VMName.vhdx"
New-VHD -Path $vhdPath -SizeBytes $DiskSize -Dynamic | Out-Null

# Attach disk to SCSI controller
Add-VMHardDiskDrive -VM $vm -Path $vhdPath

# Add DVD drive and mount ISO
Write-Host "Mounting Proxmox ISO..." -ForegroundColor Cyan
Add-VMDvdDrive -VM $vm -Path $ProxmoxISO

# Set boot order (DVD first, then HD)
$dvd = Get-VMDvdDrive -VM $vm
$hd = Get-VMHardDiskDrive -VM $vm
Set-VMFirmware -VM $vm -BootOrder $dvd, $hd

# Disable checkpoints (snapshots) to save disk space
Set-VM -VM $vm -CheckpointType Disabled

Write-Host ""
Write-Host "VM created successfully" -ForegroundColor Green
Write-Host ""
Write-Host "Starting VM..." -ForegroundColor Cyan
Start-VM -VM $vm

Write-Host ""
Write-Host "Proxmox VM started" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Connect to VM console: vmconnect.exe localhost '$VMName'"
Write-Host "  2. Or use Hyper-V Manager to connect to the VM console"
Write-Host "  3. Follow Proxmox installation wizard:"
Write-Host "     - Accept EULA"
Write-Host "     - Select target disk"
Write-Host "     - Set timezone/keyboard"
Write-Host "     - Set root password"
Write-Host "     - Configure network:"
Write-Host "       * ACCEPT DHCP VALUES initially (note the IP address)"
Write-Host "       * Management Interface: Use default (usually vmbr0)"
Write-Host "       * Hostname: proxmox-ve.local"
Write-Host "  4. After installation and reboot, login to console and note the IP"
Write-Host "  5. Configure static IP to keep the working DHCP address:"
Write-Host "     - Login to console as root"
Write-Host "     - Run: nano /etc/network/interfaces"
Write-Host "     - Change 'dhcp' to 'static' and add:"
Write-Host "       address <DHCP_IP>/20"
Write-Host "       gateway <DHCP_GATEWAY>"
Write-Host "       (Keep the gateway DHCP assigned even if it doesn't respond to ping)"
Write-Host "     - Save and run: systemctl restart networking"
Write-Host "  6. Access Proxmox web UI: https://<PROXMOX_IP>:8006"
Write-Host "  7. Run: PROXMOX_HOST=<PROXMOX_IP> ./scripts/setup-proxmox-ssh.sh"
Write-Host "  8. Run: PROXMOX_HOST=<PROXMOX_IP> ./scripts/create-proxmox-api-token.sh"
Write-Host "  9. Update appsettings.Development.json with Proxmox IP and token"
Write-Host ""
Write-Host "To stop VM later:" -ForegroundColor Cyan
Write-Host "  Stop-VM -Name '$VMName'"
Write-Host ""
Write-Host "To delete VM:" -ForegroundColor Cyan
Write-Host "  Remove-VM -Name '$VMName' -Force"
Write-Host "  Remove-Item -Path '$vmDir' -Recurse -Force"
Write-Host ""
Write-Host "Opening VM console..." -ForegroundColor Cyan
Write-Host "  vmconnect.exe localhost $VMName"
Start-Process vmconnect.exe -ArgumentList localhost,$VMName
