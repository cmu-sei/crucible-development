#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates an ESXi VM in Hyper-V with nested virtualization enabled.

.DESCRIPTION
    Creates a Generation 2 Hyper-V VM configured for running ESXi with nested virtualization support.
    The VM will be created with the ESXi ISO attached for installation.

.PARAMETER VMName
    Name of the Hyper-V VM to create. Default: crucible-esxi

.PARAMETER Memory
    Amount of RAM in GB. Default: 16

.PARAMETER CPUs
    Number of virtual CPUs. Default: 4

.PARAMETER DiskSizeGB
    Size of the virtual disk in GB. Default: 100

.PARAMETER ISOPath
    Path to the ESXi ISO file. Default: C:\ISOs\VMware-VMvisor-Installer-*.iso

.PARAMETER SwitchName
    Name of the Hyper-V virtual switch to connect to. Default: Default Switch

.EXAMPLE
    .\create-esxi-host-hyperv.ps1
    Creates ESXi VM with default settings

.EXAMPLE
    .\create-esxi-host-hyperv.ps1 -VMName "my-esxi" -Memory 32 -ISOPath "D:\ISOs\esxi8.iso"
    Creates ESXi VM with custom settings
#>

param(
    [string]$VMName = "crucible-esxi",
    [int]$Memory = 16,
    [int]$CPUs = 4,
    [int]$DiskSizeGB = 100,
    [string]$ISOPath = "",
    [string]$SwitchName = "Default Switch"
)

# Check if running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

Write-Host "Creating ESXi Host in Hyper-V" -ForegroundColor Cyan
Write-Host "  VM Name: $VMName" -ForegroundColor Gray
Write-Host "  Memory: ${Memory}GB" -ForegroundColor Gray
Write-Host "  CPUs: $CPUs" -ForegroundColor Gray
Write-Host "  Disk: ${DiskSizeGB}GB" -ForegroundColor Gray
Write-Host ""

# Find ESXi ISO if not specified
if ([string]::IsNullOrEmpty($ISOPath)) {
    $possiblePaths = @(
        ".\VMware-VMvisor-Installer-*.iso",
        "$PWD\VMware-VMvisor-Installer-*.iso",
        "C:\ISOs\VMware-VMvisor-Installer-*.iso",
        "$env:USERPROFILE\Downloads\VMware-VMvisor-Installer-*.iso"
    )

    foreach ($path in $possiblePaths) {
        $found = Get-Item $path -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $ISOPath = $found.FullName
            break
        }
    }
}

# Check if ISO exists
if ([string]::IsNullOrEmpty($ISOPath) -or -not (Test-Path $ISOPath)) {
    Write-Host "ESXi ISO not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Download ESXi 8.0 U3 or later:" -ForegroundColor Yellow
    Write-Host "  1. Register at https://customerconnect.vmware.com/" -ForegroundColor Gray
    Write-Host "  2. Navigate to: Products -> VMware vSphere" -ForegroundColor Gray
    Write-Host "  3. Download: VMware vSphere Hypervisor (ESXi ISO)" -ForegroundColor Gray
    Write-Host "  4. Place ISO in current directory or C:\ISOs\" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Searched locations:" -ForegroundColor Gray
    Write-Host "  - Current directory: $PWD" -ForegroundColor DarkGray
    Write-Host "  - C:\ISOs\" -ForegroundColor DarkGray
    Write-Host "  - $env:USERPROFILE\Downloads\" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Then run this script again." -ForegroundColor Yellow
    exit 1
}

Write-Host "[OK] Found ESXi ISO: $ISOPath" -ForegroundColor Green

# Check if VM already exists
$existingVM = Get-VM -Name $VMName -ErrorAction SilentlyContinue
if ($existingVM) {
    Write-Host "[ERROR] VM '$VMName' already exists" -ForegroundColor Red
    Write-Host "Remove it first with: Remove-VM -Name '$VMName' -Force" -ForegroundColor Yellow
    exit 1
}

# Check if virtual switch exists
$switch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
if (-not $switch) {
    Write-Host "[ERROR] Virtual switch '$SwitchName' not found" -ForegroundColor Red
    Write-Host "Available switches:" -ForegroundColor Yellow
    Get-VMSwitch | Format-Table Name, SwitchType
    exit 1
}

# Create VM directory
$vmPath = "C:\Hyper-V\$VMName"
if (-not (Test-Path $vmPath)) {
    New-Item -Path $vmPath -ItemType Directory -Force | Out-Null
}

Write-Host "Creating VM..." -ForegroundColor Cyan

# Create VM (Generation 2 required for UEFI)
$vm = New-VM `
    -Name $VMName `
    -Generation 2 `
    -MemoryStartupBytes ($Memory * 1GB) `
    -Path "C:\Hyper-V" `
    -SwitchName $SwitchName

# Create virtual hard disk
$vhdPath = "$vmPath\Virtual Hard Disks\$VMName.vhdx"
New-VHD -Path $vhdPath -SizeBytes ($DiskSizeGB * 1GB) -Dynamic | Out-Null
Add-VMHardDiskDrive -VM $vm -Path $vhdPath

Write-Host "[OK] VM created" -ForegroundColor Green

# Configure VM
Write-Host "Configuring VM..." -ForegroundColor Cyan

# Set CPU count
Set-VMProcessor -VM $vm -Count $CPUs

# Enable nested virtualization (CRITICAL for ESXi)
Set-VMProcessor -VM $vm -ExposeVirtualizationExtensions $true

# Set static memory (dynamic memory not supported with nested virtualization)
Set-VMMemory -VM $vm -DynamicMemoryEnabled $false

# Disable Secure Boot (ESXi doesn't support it)
Set-VMFirmware -VM $vm -EnableSecureBoot Off

# Add DVD drive and mount ISO
Add-VMDvdDrive -VM $vm
$dvd = Get-VMDvdDrive -VM $vm
Set-VMDvdDrive -VMDvdDrive $dvd -Path $ISOPath

# Set boot order: DVD first, then HDD
$dvdBoot = Get-VMFirmware -VM $vm | Select-Object -ExpandProperty BootOrder | Where-Object { $_.Device -is [Microsoft.HyperV.PowerShell.DvdDrive] }
$hddBoot = Get-VMFirmware -VM $vm | Select-Object -ExpandProperty BootOrder | Where-Object { $_.Device -is [Microsoft.HyperV.PowerShell.HardDiskDrive] }
Set-VMFirmware -VM $vm -BootOrder $dvdBoot, $hddBoot

# Enable MAC address spoofing (may be needed for nested VMs)
Get-VMNetworkAdapter -VM $vm | Set-VMNetworkAdapter -MacAddressSpoofing On

Write-Host "[OK] VM configured" -ForegroundColor Green
Write-Host ""
Write-Host "VM Configuration:" -ForegroundColor Cyan
Write-Host "  Memory: $Memory GB (static)" -ForegroundColor Gray
Write-Host "  CPUs: $CPUs (nested virtualization enabled)" -ForegroundColor Gray
Write-Host "  Disk: $DiskSizeGB GB" -ForegroundColor Gray
Write-Host "  Network: $SwitchName" -ForegroundColor Gray
Write-Host "  ISO: $ISOPath" -ForegroundColor Gray
Write-Host ""

# Ask if user wants to start VM
$startVM = Read-Host "Start VM and open console for ESXi installation? (y/n)"
if ($startVM -eq 'y' -or $startVM -eq 'Y') {
    Write-Host "Starting VM..." -ForegroundColor Cyan
    Start-VM -VM $vm

    # Wait a moment for VM to start
    Start-Sleep -Seconds 2

    # Open VM Connect console
    vmconnect.exe localhost $VMName

    Write-Host ""
    Write-Host "ESXi Installation Steps:" -ForegroundColor Yellow
    Write-Host "  1. Wait for ESXi installer to boot" -ForegroundColor Gray
    Write-Host "  2. Press Enter to start installation" -ForegroundColor Gray
    Write-Host "  3. Accept license (F11)" -ForegroundColor Gray
    Write-Host "  4. Select disk for installation" -ForegroundColor Gray
    Write-Host "  5. Set root password" -ForegroundColor Gray
    Write-Host "  6. Confirm installation (F11)" -ForegroundColor Gray
    Write-Host "  7. After installation, configure network with static IP" -ForegroundColor Gray
    Write-Host "  8. Enable SSH: Troubleshooting Options -> Enable SSH" -ForegroundColor Gray
    Write-Host ""
    Write-Host "After installation, run: .\scripts\setup-esxi-ssh.sh" -ForegroundColor Green
}
else {
    Write-Host ""
    Write-Host "VM created but not started." -ForegroundColor Yellow
    Write-Host "Start manually with: Start-VM -Name $VMName" -ForegroundColor Gray
    Write-Host "Open console with: vmconnect.exe localhost $VMName" -ForegroundColor Gray
}
