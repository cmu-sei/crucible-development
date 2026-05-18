#!/bin/bash
# Toggle TopoMojo between Proxmox, vSphere on-prem, and VMware Cloud (VMC)
# by creating/updating appsettings.Development.conf

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOPOMOJO_API_DIR="/mnt/data/crucible/topomojo/topomojo/src/TopoMojo.Api"
APPSETTINGS_DEV="$TOPOMOJO_API_DIR/appsettings.Development.conf"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration profiles
declare -A PROXMOX=(
    [name]="Proxmox (Local)"
    [type]="Proxmox"
    [url]="https://172.22.64.132:443"
    [user]=""
    [password]=""
    [access_token]="root@pam!crucible=6d803e6b-5af5-4c02-bb9e-19f57094875c"
    [vm_store]="local-lvm"
    [disk_store]="local-lvm"
    [iso_store]="local"
    [iso_root]="/mnt/proxmox-iso"
    [pool_path]=""
    [ignore_cert_errors]="true"
    [ticket_url_handler]="none"
    [use_datastore_api]="false"
    [temp_root]="/tmp/topoiso"
)

declare -A VSPHERE=(
    [name]="vSphere (On-Prem)"
    [type]="Vsphere"
    [url]="https://vcenter.example.com/sdk"
    [user]="administrator@vsphere.local"
    [password]="your-password-here"
    [access_token]=""
    [vm_store]="[datastore] topomojo"
    [disk_store]="[datastore] topomojo"
    [iso_store]="[datastore] topomojo"
    [iso_root]="/mnt/isos"
    [pool_path]="Datacenter/Cluster"
    [ignore_cert_errors]="true"
    [ticket_url_handler]="querystring"
    [use_datastore_api]="false"
    [temp_root]="/tmp/topoiso"
)

declare -A VMC=(
    [name]="VMware Cloud on AWS"
    [type]="vSphere"
    [url]="https://vcenter.sddc-xx-xx-xx-xx.vmwarevmc.com/sdk"
    [user]="cloudadmin@vmc.local"
    [password]="your-vmc-password-here"
    [access_token]=""
    [vm_store]="[WorkloadDatastore] topomojo/"
    [disk_store]="[WorkloadDatastore] topomojo/"
    [iso_store]="[WorkloadDatastore] topomojo/"
    [file_iso_store]="[WorkloadDatastore] topomojo/"
    [iso_root]="/mnt/vmc-iso"
    [pool_path]="SDDC-Datacenter/Cluster-1/Compute-ResourcePool"
    [ignore_cert_errors]="true"
    [ticket_url_handler]="none"
    [use_datastore_api]="true"
    [temp_root]="/tmp/topoiso"
)

show_current_config() {
    echo -e "${BLUE}Current TopoMojo Hypervisor Configuration:${NC}"
    echo ""

    if [ -f "$APPSETTINGS_DEV" ]; then
        local current_type=$(grep "^Pod__HypervisorType" "$APPSETTINGS_DEV" 2>/dev/null | cut -d= -f2 | xargs || echo "Not set")
        local current_url=$(grep "^Pod__Url" "$APPSETTINGS_DEV" 2>/dev/null | cut -d= -f2 | xargs || echo "Not set")
        local current_api=$(grep "^FileUpload__UseDatastoreApi" "$APPSETTINGS_DEV" 2>/dev/null | cut -d= -f2 | xargs || echo "false")

        echo "  Type:    $current_type"
        echo "  URL:     $current_url"
        echo "  API Upload: $current_api"
    else
        echo "  ${YELLOW}No appsettings.Development.conf found${NC}"
        echo "  Using defaults from appsettings.conf"
    fi
    echo ""
}

prompt_for_credentials() {
    local profile=$1
    local -n config=$profile

    if [ "$profile" == "VMC" ] || [ "$profile" == "VSPHERE" ]; then
        # Apply command-line arguments if provided
        if [ -n "$CLI_URL" ]; then
            config[url]="$CLI_URL"
        fi
        if [ -n "$CLI_USER" ]; then
            config[user]="$CLI_USER"
        fi
        if [ -n "$CLI_PASSWORD" ]; then
            config[password]="$CLI_PASSWORD"
        fi
        if [ -n "$CLI_POOL_PATH" ]; then
            config[pool_path]="$CLI_POOL_PATH"
        fi
        if [ -n "$CLI_DATASTORE" ]; then
            config[vm_store]="[$CLI_DATASTORE] topomojo"
            config[disk_store]="[$CLI_DATASTORE] topomojo"
            config[iso_store]="[$CLI_DATASTORE] topomojo"
        fi

        # Skip prompts if non-interactive
        if [ "$NON_INTERACTIVE" == "true" ]; then
            return
        fi

        echo -e "${BLUE}════════════════════════════════════════════════${NC}"
        echo -e "${BLUE}      ${config[name]} Credentials      ${NC}"
        echo -e "${BLUE}════════════════════════════════════════════════${NC}"
        echo ""

        # vCenter URL
        echo -e "${YELLOW}vCenter URL:${NC}"
        if [ "$profile" == "VMC" ]; then
            echo "  Example: https://vcenter.sddc-12-34-56-78.vmwarevmc.com/sdk"
        else
            echo "  Example: https://vcenter.example.com/sdk"
        fi
        read -p "Enter URL [${config[url]}]: " input_url
        config[url]="${input_url:-${config[url]}}"

        # Username
        echo ""
        echo -e "${YELLOW}Username:${NC}"
        read -p "Enter username [${config[user]}]: " input_user
        config[user]="${input_user:-${config[user]}}"

        # Password
        echo ""
        echo -e "${YELLOW}Password:${NC}"
        read -s -p "Enter password: " input_password
        echo ""
        if [ -n "$input_password" ]; then
            config[password]="$input_password"
        fi

        # Pool Path
        if [ "$profile" == "VMC" ]; then
            echo ""
            echo -e "${YELLOW}Pool Path:${NC}"
            echo "  Usually: SDDC-Datacenter/Compute-ResourcePool"
            read -p "Enter pool path [${config[pool_path]}]: " input_pool
            config[pool_path]="${input_pool:-${config[pool_path]}}"
        fi

        # Datastore
        echo ""
        echo -e "${YELLOW}Datastore Name:${NC}"
        if [ "$profile" == "VMC" ]; then
            echo "  Usually: WorkloadDatastore"
        else
            echo "  Example: datastore1"
        fi
        local current_ds=$(echo "${config[iso_store]}" | sed -n 's/\[\([^]]*\)\].*/\1/p')
        read -p "Enter datastore name [$current_ds]: " input_ds
        if [ -n "$input_ds" ]; then
            config[vm_store]="[$input_ds] topomojo"
            config[disk_store]="[$input_ds] topomojo"
            config[iso_store]="[$input_ds] topomojo"
        fi

        echo ""
        echo -e "${GREEN}✓ Credentials collected${NC}"
        echo ""
    elif [ "$profile" == "PROXMOX" ]; then
        echo -e "${BLUE}Using Proxmox configuration${NC}"
        echo "  (Token-based authentication)"
        echo ""
    fi
}

write_appsettings() {
    local profile=$1
    local -n config=$profile

    echo -e "${YELLOW}Writing appsettings.Development.conf${NC}"
    echo ""

    # Create the config file
    cat > "$APPSETTINGS_DEV" <<EOF
####################
## TopoMojo Development Configuration
## Profile: ${config[name]}
## Generated by toggle-topomojo-hypervisor.sh
####################

####################
## Hypervisor Configuration
####################
Pod__Type = ${config[type]}
Pod__HypervisorType = ${config[type]}
Pod__Url = ${config[url]}
EOF

    # Add authentication
    if [ -n "${config[user]}" ]; then
        echo "Pod__User = ${config[user]}" >> "$APPSETTINGS_DEV"
    fi

    if [ -n "${config[password]}" ]; then
        echo "Pod__Password = ${config[password]}" >> "$APPSETTINGS_DEV"
    fi

    if [ -n "${config[access_token]}" ]; then
        echo "Pod__AccessToken = ${config[access_token]}" >> "$APPSETTINGS_DEV"
    fi

    # Add storage paths
    cat >> "$APPSETTINGS_DEV" <<EOF
Pod__VmStore = ${config[vm_store]}
Pod__DiskStore = ${config[disk_store]}
Pod__IsoStore = ${config[iso_store]}
EOF

    # Add pool path if present
    if [ -n "${config[pool_path]}" ]; then
        echo "Pod__PoolPath = ${config[pool_path]}" >> "$APPSETTINGS_DEV"
    fi

    # Add additional settings
    cat >> "$APPSETTINGS_DEV" <<EOF
Pod__IgnoreCertificateErrors = ${config[ignore_cert_errors]}
Pod__TicketUrlHandler = ${config[ticket_url_handler]}

####################
## File Upload Configuration
####################
FileUpload__IsoRoot = ${config[iso_root]}
EOF

    # Add FileUpload__IsoStore for VMC only
    if [ -n "${config[file_iso_store]}" ]; then
        echo "FileUpload__IsoStore = ${config[file_iso_store]}" >> "$APPSETTINGS_DEV"
    fi

    cat >> "$APPSETTINGS_DEV" <<EOF
FileUpload__UseDatastoreApi = ${config[use_datastore_api]}
FileUpload__TempRoot = ${config[temp_root]}
EOF

    echo "  ✓ Created/updated appsettings.Development.conf"
    echo ""
}

apply_config() {
    local profile=$1
    local -n config=$profile

    # Prompt for credentials if needed
    prompt_for_credentials "$profile"

    echo -e "${YELLOW}Switching to: ${config[name]}${NC}"
    echo ""

    # Write the appsettings file
    write_appsettings "$profile"

    echo -e "${GREEN}Successfully switched to: ${config[name]}${NC}"
    echo ""
    echo -e "${YELLOW}Configuration details:${NC}"
    echo "  Type:       ${config[type]}"
    echo "  URL:        ${config[url]}"
    echo "  VM Store:   ${config[vm_store]}"
    echo "  ISO API:    ${config[use_datastore_api]}"
    echo ""

    # Show VMC-specific instructions
    if [ "$profile" == "VMC" ]; then
        echo -e "${YELLOW}✓ VMC Configuration Notes:${NC}"
        echo "  • TopoMojo will create 'topomojo/' folder on WorkloadDatastore"
        echo "  • ISOs stored in: [WorkloadDatastore] topomojo/00000000.../*.iso"
        echo "  • Uses vSphere API for uploads (NFS not required)"
        echo ""
    fi

    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. Review config: cat $APPSETTINGS_DEV"
    echo "  2. Restart Aspire: aspire run"
    echo "  3. To revert: rm $APPSETTINGS_DEV"
    echo ""
}

remove_config() {
    if [ -f "$APPSETTINGS_DEV" ]; then
        rm "$APPSETTINGS_DEV"
        echo -e "${GREEN}✓ Removed appsettings.Development.conf${NC}"
        echo "  (Will use defaults from appsettings.conf)"
    else
        echo -e "${YELLOW}No appsettings.Development.conf to remove${NC}"
    fi
}

show_menu() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   TopoMojo Hypervisor Configuration Toggle    ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
    echo ""

    show_current_config

    echo "Select hypervisor configuration:"
    echo ""
    echo "  1) ${PROXMOX[name]}"
    echo "     • Local Proxmox server"
    echo "     • NFS not required (uses local storage)"
    echo ""
    echo "  2) ${VSPHERE[name]}"
    echo "     • Traditional vSphere/vCenter"
    echo "     • Requires NFS mount for ISO uploads"
    echo ""
    echo "  3) ${VMC[name]}"
    echo "     • VMware Cloud SDDC"
    echo "     • Uses vSphere API for ISO uploads (no NFS)"
    echo ""
    echo "  r) Remove config (use defaults)"
    echo "  q) Quit"
    echo ""
}

show_usage() {
    echo "Usage: $0 [profile] [options]"
    echo ""
    echo "Profiles:"
    echo "  proxmox    - Switch to Proxmox configuration"
    echo "  vsphere    - Switch to vSphere on-premises configuration"
    echo "  vmc        - Switch to VMware Cloud on AWS configuration"
    echo "  remove     - Remove Development config (use defaults)"
    echo ""
    echo "Options for vsphere/vmc:"
    echo "  --url URL              vCenter URL (e.g., https://vcenter.example.com/sdk)"
    echo "  --user USERNAME        vCenter username (e.g., administrator@vsphere.local)"
    echo "  --password PASSWORD    vCenter password"
    echo "  --pool-path PATH       Resource pool path (e.g., SDDC-Datacenter/Compute-ResourcePool)"
    echo "  --datastore NAME       Datastore name (e.g., WorkloadDatastore)"
    echo "  --non-interactive      Skip all prompts (use defaults or provided values)"
    echo ""
    echo "Examples:"
    echo "  # Interactive mode (prompts for credentials)"
    echo "  $0 vmc"
    echo ""
    echo "  # Non-interactive with credentials"
    echo "  $0 vmc --url https://vcenter.sddc-xx.vmwarevmc.com/sdk \\"
    echo "         --user cloudadmin@vmc.local \\"
    echo "         --password 'MyP@ssw0rd!' \\"
    echo "         --non-interactive"
}

parse_args() {
    local profile=$1
    shift

    NON_INTERACTIVE=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --url)
                CLI_URL="$2"
                shift 2
                ;;
            --user)
                CLI_USER="$2"
                shift 2
                ;;
            --password)
                CLI_PASSWORD="$2"
                shift 2
                ;;
            --pool-path)
                CLI_POOL_PATH="$2"
                shift 2
                ;;
            --datastore)
                CLI_DATASTORE="$2"
                shift 2
                ;;
            --non-interactive)
                NON_INTERACTIVE=true
                shift
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_usage
                exit 1
                ;;
        esac
    done
}

main() {
    # Check if TopoMojo API directory exists
    if [ ! -d "$TOPOMOJO_API_DIR" ]; then
        echo -e "${RED}Error: TopoMojo API directory not found at $TOPOMOJO_API_DIR${NC}"
        exit 1
    fi

    # Show usage if requested
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        show_usage
        exit 0
    fi

    # Interactive mode
    if [ $# -eq 0 ]; then
        while true; do
            show_menu
            read -p "Enter choice: " choice
            echo ""

            case $choice in
                1)
                    apply_config PROXMOX
                    read -p "Press Enter to continue..."
                    ;;
                2)
                    apply_config VSPHERE
                    echo -e "${YELLOW}⚠ Don't forget to configure NFS mount!${NC}"
                    read -p "Press Enter to continue..."
                    ;;
                3)
                    apply_config VMC
                    read -p "Press Enter to continue..."
                    ;;
                r|R)
                    remove_config
                    read -p "Press Enter to continue..."
                    ;;
                q|Q)
                    echo "Goodbye!"
                    exit 0
                    ;;
                *)
                    echo -e "${RED}Invalid choice${NC}"
                    sleep 1
                    ;;
            esac
        done
    else
        # Command-line mode
        profile=$1
        shift
        parse_args "$profile" "$@"

        case $profile in
            proxmox)
                apply_config PROXMOX
                ;;
            vsphere)
                apply_config VSPHERE
                if [ "$NON_INTERACTIVE" != "true" ]; then
                    echo -e "${YELLOW}⚠ Don't forget to configure NFS mount!${NC}"
                fi
                ;;
            vmc)
                apply_config VMC
                ;;
            remove)
                remove_config
                ;;
            *)
                echo -e "${RED}Unknown profile: $profile${NC}"
                echo ""
                show_usage
                exit 1
                ;;
        esac
    fi
}

main "$@"
