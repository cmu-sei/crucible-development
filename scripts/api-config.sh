#!/usr/bin/env bash
# Shared by configure-hypervisors.sh, toggle-hypervisor.sh and Proxmox provisioning.
# Requires Bash 4.4+ and jq, both included in the development container.

API_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_APPHOST="$(cd "$API_SCRIPT_DIR/../Crucible.AppHost" && pwd)"
API_CONFIG_ROOT="$API_APPHOST/resources/api/config"

api_die() { printf '%s\n' "$*" >&2; exit 1; }
api_name() { [[ $1 =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; }
api_trim() {
    API_TRIMMED="${1#"${1%%[![:space:]]*}"}"
    API_TRIMMED="${API_TRIMMED%"${API_TRIMMED##*[![:space:]]}"}"
}
api_valid_value() {
    api_trim "$1"
    [[ -n $1 && $1 == "$API_TRIMMED" && ! $1 =~ [[:cntrl:]] ]]
}
api_valid_host() {
    # Hostname/IPv4, or bracketed IPv6; no URL scheme, port, path or credentials.
    [[ $1 =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ||
       ( $1 =~ ^\[[a-fA-F0-9:.]+\]$ && $1 == *:* ) ]]
}

api_read_conf() {
    local file=$1 line key count=0
    API_CONF_KEYS=()
    API_CONF_VALUES=()
    [[ -f $file ]] || api_die "Missing configuration file: $file"
    while IFS= read -r line || [[ -n $line ]]; do
        count=$((count + 1))
        if ((count == 1)); then line=${line#$'\xef\xbb\xbf'}; fi
        api_trim "$line"
        [[ -z $API_TRIMMED || $API_TRIMMED == \#* ]] && continue
        [[ $line == *=* ]] || api_die "$file, line $count: expected KEY=value"
        api_trim "${line%%=*}"; key=$API_TRIMMED
        [[ $key =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || api_die "$file, line $count: invalid environment key"
        [[ ! ${API_CONF_VALUES[${key,,}]+present} ]] || api_die "$file, line $count: duplicate environment key"
        api_trim "${line#*=}"
        API_CONF_KEYS+=("$key")
        API_CONF_VALUES[${key,,}]=$API_TRIMMED
    done < "$file"
}

api_placeholders() {
    local file value marker pattern='<[^>]+>'
    API_PLACEHOLDERS=()
    for file in "$API_CONFIG_ROOT"/templates/*/*.conf.template; do
        api_read_conf "$file"
        for value in "${API_CONF_VALUES[@]}"; do
            while [[ $value =~ $pattern ]]; do
                marker=${BASH_REMATCH[0]}
                API_PLACEHOLDERS["$marker"]=1
                value=${value#*"$marker"}
            done
        done
    done
}

api_check_complete() {
    local key marker
    api_read_conf "$1"
    for key in "${API_CONF_KEYS[@]}"; do
        for marker in "${!API_PLACEHOLDERS[@]}"; do
            [[ ${API_CONF_VALUES[${key,,}]} != *"$marker"* ]] ||
                api_die "Unfilled template placeholder for $key in $1. Regenerate with guided setup or edit the file."
        done
    done
}

# Only paths returned by mktemp enter this list. EXIT cleans up on failure or Ctrl-C.
api_temp_file() {
    API_TEMP_FILE=$(mktemp "$1")
    API_TEMP_FILES+=("$API_TEMP_FILE")
}
api_cleanup() {
    if ((${#API_TEMP_FILES[@]})); then rm -f -- "${API_TEMP_FILES[@]}"; fi
}
api_write() {
    api_temp_file "$1.XXXXXX.tmp"
    printf '%s\n' "$2" > "$API_TEMP_FILE"
    mv -T -- "$API_TEMP_FILE" "$1"
}

api_render() {
    local file=$1 line rest marker pattern='<[^>]+>'
    API_RENDERED=
    while IFS= read -r line || [[ -n $line ]]; do
        api_trim "$line"
        if [[ $API_TRIMMED != \#* && ${#API_REPLACEMENTS[@]} -gt 0 ]]; then
            rest=$line; line=
            # Scan template text only once: replacements are literal, never re-expanded.
            while [[ $rest =~ $pattern ]]; do
                marker=${BASH_REMATCH[0]}
                [[ ${API_REPLACEMENTS["$marker"]+present} ]] ||
                    api_die "Unfilled template placeholder in $file: $marker"
                line+="${rest%%"$marker"*}${API_REPLACEMENTS["$marker"]}"
                rest=${rest#*"$marker"}
            done
            line+=$rest
        fi
        API_RENDERED+="$line"$'\n'
    done < "$file"
}

api_initialize() {
    local template=$1 profile=$2 regenerate=${3:-false} file target backup i
    api_name "$template" && api_name "$profile" || api_die 'Invalid template or profile name.'
    [[ $profile != remove ]] || api_die '"remove" is reserved for disabling API configuration.'
    [[ -d $API_CONFIG_ROOT/templates/$template ]] || api_die "Unknown template set: $template"
    local directory="$API_CONFIG_ROOT/local/$profile"
    local -a targets=() contents=()
    for file in "$API_CONFIG_ROOT/templates/$template"/*.conf.template; do
        target="$directory/$(basename "${file%.template}")"
        if [[ -e $target && $regenerate == false ]]; then
            printf 'Preserved %s\n' "$target"
            continue
        fi
        api_render "$file"
        targets+=("$target"); contents+=("${API_RENDERED%$'\n'}")
    done
    # Render every file before making backups or replacing any existing config.
    mkdir -p -- "$directory"
    chmod 700 -- "$API_CONFIG_ROOT/local" "$directory"
    for target in "${targets[@]}"; do
        if [[ -e $target ]]; then
            backup=$(mktemp "$target.$(date +%Y%m%dT%H%M%S).XXXXXX.bak")
            cp -- "$target" "$backup"
            printf 'Backed up %s\n' "$backup"
        fi
    done
    for i in "${!targets[@]}"; do
        api_write "${targets[$i]}" "${contents[$i]}"
        printf 'Created %s\n' "${targets[$i]}"
    done
}

api_settings() {
    local local_file="$API_APPHOST/appsettings.Development.json" base_file=/dev/null
    [[ -f $local_file ]] || local_file=/dev/null
    if [[ $1 == select && $2 != remove ]]; then base_file="$API_APPHOST/appsettings.json"; fi
    # Read JSON through files, not process arguments, which might expose secrets.
    jq -nr --arg mode "$1" --arg profile "${2:-}" --arg local_file "$local_file" \
        --rawfile local_text "$local_file" --rawfile base_text "$base_file" \
        -f "$API_SCRIPT_DIR/api-config.jq" 2>/dev/null ||
        api_die 'Invalid AppHost JSON settings. Check appsettings.json and appsettings.Development.json.'
}

api_toggle() {
    local profile=$1 document required app
    if [[ $profile != remove ]]; then
        api_name "$profile" || api_die 'Profile names must start with a letter or digit and contain only letters, digits, "-" and "_".'
        [[ -d $API_CONFIG_ROOT/local/$profile ]] || api_die "Initialize the local profile first: $profile"
    fi
    document=$(api_settings select "$profile")
    required=$(printf '%s\n' "$document" | jq -r '.required[]')
    if [[ -n $required ]]; then
        api_placeholders
        while IFS= read -r app; do
            api_check_complete "$API_CONFIG_ROOT/local/$profile/$app.conf"
        done <<< "$required"
    fi
    api_write "$API_APPHOST/appsettings.Development.json" "$(printf '%s\n' "$document" | jq '.settings')"
    if [[ $profile == remove ]]; then printf 'API file configuration disabled.\n'
    else printf 'Selected API profile: %s\n' "$profile"; fi
    printf 'Restart Aspire to apply. Environment variables and user secrets can override launch settings.\n'
}

api_saved_proxmox() {
    API_PROXMOX_HOST=${PROXMOX_HOST:-}
    API_PROXMOX_TOKEN=${PROXMOX_API_TOKEN:-}
    [[ -n $API_PROXMOX_HOST && -n $API_PROXMOX_TOKEN ]] && return 0
    local file candidate
    local -a saved=() candidates=()
    if [[ -n ${PROXMOX_CONFIG_FILE:-} ]]; then candidates=("$PROXMOX_CONFIG_FILE")
    else candidates=("$API_APPHOST/resources/proxmox/config" "$HOME/.crucible-proxmox"); fi
    for candidate in "${candidates[@]}"; do
        [[ -f $candidate ]] || continue
        file=$candidate
        api_temp_file "${TMPDIR:-/tmp}/crucible-api.XXXXXX"
        # Provisioning saves a shell file using printf %q, not a literal .conf file.
        timeout 5 bash -c 'source "$1" >/dev/null 2>&1 || exit; printf "%s\0%s\0" "${PROXMOX_HOST:-}" "${PROXMOX_API_TOKEN:-}"' \
            -- "$file" > "$API_TEMP_FILE" 2>/dev/null || api_die "Could not load saved Proxmox configuration: $file"
        mapfile -d '' -t saved < "$API_TEMP_FILE"
        API_PROXMOX_HOST=${API_PROXMOX_HOST:-${saved[0]:-}}
        API_PROXMOX_TOKEN=${API_PROXMOX_TOKEN:-${saved[1]:-}}
        break
    done
}

api_terminal() {
    [[ -t 0 && -t 1 ]] || api_die 'Guided setup needs a terminal. Use init to create files manually, or select an existing profile.'
}
api_ask() {
    local label=$1 fallback=$2 secret=$3
    printf '%s' "$label"
    if [[ -n $fallback ]]; then
        if [[ $secret == true ]]; then printf ' [saved value; Enter to keep]'
        else printf ' [%s]' "$fallback"; fi
    fi
    printf ': '
    if [[ $secret == true ]]; then
        # Bash restores terminal echo when read -s returns or is interrupted.
        IFS= read -r -s API_ANSWER || api_die $'\nSetup cancelled; no profile was generated.'
        printf '\n'
    else
        IFS= read -r API_ANSWER || api_die $'\nSetup cancelled; no profile was generated.'
    fi
    API_ANSWER=${API_ANSWER:-$fallback}
}
api_prompt() {
    local label=$1 fallback=${2:-} secret=${3:-false} kind=${4:-text} valid
    while true; do
        api_ask "$label" "$fallback" "$secret"
        valid=false
        if api_valid_value "$API_ANSWER"; then
            case $kind in
                text) valid=true ;;
                host) if api_valid_host "$API_ANSWER"; then valid=true; fi ;;
                port) if [[ $API_ANSWER =~ ^[0-9]{1,5}$ ]] && ((10#$API_ANSWER > 0 && 10#$API_ANSWER <= 65535)); then valid=true; fi ;;
                name) if api_name "$API_ANSWER" && [[ $API_ANSWER != remove ]]; then valid=true; fi ;;
                datastore) if [[ $API_ANSWER != *'['* && $API_ANSWER != *']'* ]]; then valid=true; fi ;;
                pool) if [[ $API_ANSWER == */* && $API_ANSWER != /* && $API_ANSWER != */ &&
                            $API_ANSWER != *//* && ! $API_ANSWER =~ /[[:space:]]*/ ]]; then valid=true; fi ;;
            esac
        fi
        [[ $valid == true ]] && return 0
        printf 'Enter a valid %s (one line, without surrounding whitespace).\n' "${label,,}"
    done
}
api_choose() {
    local label=$1 fallback=$2 choice
    shift 2
    printf 'Choices: %s\n' "$*"
    while true; do
        api_ask "$label" "$fallback" false
        for choice in "$@"; do [[ $API_ANSWER == "$choice" ]] && return 0; done
        printf 'Choose one of: %s\n' "$*"
    done
}

api_configure() {
    local template=$1 profile=$2 regenerate=false host username password datastore pool remainder
    [[ $template == proxmox || $template == vsphere ]] || api_die 'Guided setup supports proxmox and vsphere.'
    api_name "$profile" && [[ $profile != remove ]] || api_die 'Invalid or reserved profile name.'
    local directory="$API_CONFIG_ROOT/local/$profile"
    local -a existing=("$directory"/*.conf)
    if ((${#existing[@]})); then
        printf 'Existing profile: %s\n' "$directory"
        api_choose 'Keep files or regenerate from templates (backs up existing files)' keep keep regenerate cancel
        case $API_ANSWER in
            keep) api_toggle "$profile"; return ;;
            cancel) api_die 'Setup cancelled; existing files were kept.' ;;
            regenerate) regenerate=true ;;
        esac
    fi
    API_REPLACEMENTS=()
    if [[ $template == proxmox ]]; then
        api_saved_proxmox
        api_prompt 'Proxmox host (hostname or IP only)' "$API_PROXMOX_HOST" false host
        API_REPLACEMENTS['<proxmox-host>']=$API_ANSWER
        api_prompt 'Proxmox port' 443 false port
        API_REPLACEMENTS['<proxmox-port>']=$API_ANSWER
        api_prompt 'Proxmox API token' "$API_PROXMOX_TOKEN" true
        API_REPLACEMENTS['<user@realm!token-id=token-secret>']=$API_ANSWER
        api_prompt 'VM and disk storage' local-lvm
        API_REPLACEMENTS['<vm-storage>']=$API_ANSWER
        api_prompt 'ISO storage' local
        API_REPLACEMENTS['<iso-storage>']=$API_ANSWER
    else
        api_prompt 'vCenter host (hostname or IP only)' '' false host; host=$API_ANSWER
        api_prompt 'vCenter username' administrator@vsphere.local; username=$API_ANSWER
        api_prompt 'vCenter password' '' true; password=$API_ANSWER
        api_prompt 'Datastore name' datastore1 false datastore; datastore=$API_ANSWER
        api_prompt 'Pool path (Datacenter/Cluster[/ResourcePool])' Datacenter/Cluster false pool; pool=$API_ANSWER
        remainder=${pool#*/}
        API_REPLACEMENTS=(
            ['<vcenter-host>']="$host" ['<username>']="$username" ['<password>']="$password"
            ['<datastore>']="$datastore" ['<pool-path>']="$pool"
            ['<datacenter>']="${pool%%/*}" ['<cluster>']="${remainder%%/*}" ['<resource-pool>']=''
        )
        if [[ $remainder == */* ]]; then API_REPLACEMENTS['<resource-pool>']=${remainder#*/}; fi
    fi
    api_initialize "$template" "$profile" "$regenerate"
    api_toggle "$profile"
    printf 'Advanced settings can be edited in %s/*.conf.\n' "$directory"
    if [[ $template == vsphere ]]; then
        printf 'ISO uploads use /mnt/isos. Ensure the matching NFS mount is available, or edit the upload settings.\n'
    fi
}

api_menu() {
    local template directory status
    local -a profiles=()
    status=$(api_settings status)
    printf 'API profiles: %s\n' "$status"
    api_choose Action configure configure select disable quit
    case $API_ANSWER in
        quit) return ;;
        disable) api_toggle remove; return ;;
        select)
            for directory in "$API_CONFIG_ROOT/local"/*/; do profiles+=("$(basename "$directory")"); done
            ((${#profiles[@]})) || api_die 'No local profiles yet. Run configure-hypervisors.sh to create one.'
            api_choose Profile '' "${profiles[@]}"
            api_toggle "$API_ANSWER"; return ;;
    esac
    api_choose Backend proxmox proxmox vsphere; template=$API_ANSWER
    api_prompt 'Profile name' "$template" false name
    api_configure "$template" "$API_ANSWER"
}

api_config_main() (
    set +x
    set -euo pipefail
    umask 077
    export LC_ALL=C
    shopt -s nullglob
    ((BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4))) ||
        api_die 'Bash 4.4 or newer is required for API profile setup.'
    command -v jq >/dev/null || api_die 'jq is required for API profile setup.'
    local -a API_TEMP_FILES=() API_CONF_KEYS=()
    local -A API_CONF_VALUES=() API_PLACEHOLDERS=() API_REPLACEMENTS=()
    trap api_cleanup EXIT
    trap 'api_die "Setup cancelled."' INT TERM
    local command=${1:-} action=${2:-} profile file
    shift "$(($# > 1 ? 2 : $#))"
    case $command in
        configure)
            case $action in
                '') api_terminal; api_menu ;;
                help|--help)
                    printf 'Usage: configure-hypervisors.sh [proxmox|vsphere [--profile NAME]] | list | init TEMPLATE [--profile NAME]\n'
                    printf 'Without arguments, opens a menu. Guided setup fills templates and selects the profile.\n' ;;
                list)
                    (($# == 0)) || api_die 'Use list without additional arguments.'
                    for file in "$API_CONFIG_ROOT/templates"/*/; do basename "$file"; done ;;
                init)
                    (($# == 1 || $# == 3)) || api_die 'Use init TEMPLATE [--profile NAME].'
                    if (($# == 3)); then [[ $2 == --profile ]] || api_die 'Expected --profile NAME.'; fi
                    api_initialize "$1" "${3:-$1}"
                    printf 'Edit the local files, then select with: ./scripts/toggle-hypervisor.sh %s\n' "${3:-$1}" ;;
                proxmox|vsphere)
                    (($# == 0 || $# == 2)) || api_die 'Use BACKEND [--profile NAME].'
                    if (($# == 2)); then [[ $1 == --profile ]] || api_die 'Expected --profile NAME.'; fi
                    api_terminal; api_configure "$action" "${2:-$action}" ;;
                *) api_die 'Unknown setup command. Run configure-hypervisors.sh --help.' ;;
            esac ;;
        toggle)
            (($# == 0)) || api_die 'Use toggle-hypervisor.sh PROFILE | remove.'
            case $action in
                '') api_terminal; api_menu ;;
                help|--help) printf 'Usage: toggle-hypervisor.sh [PROFILE | remove]. Without arguments, opens a menu.\n' ;;
                *)
                    if [[ ( $action == proxmox || $action == vsphere ) && ! -d $API_CONFIG_ROOT/local/$action ]]; then
                        api_terminal; api_configure "$action" "$action"
                    else api_toggle "$action"; fi ;;
            esac ;;
        setup-proxmox)
            api_valid_value "${PROXMOX_HOST:-}" && api_valid_host "$PROXMOX_HOST" &&
                api_valid_value "${PROXMOX_API_TOKEN:-}" || api_die 'Proxmox setup requires single-line PROXMOX_HOST and PROXMOX_API_TOKEN values.'
            if [[ -t 0 && -t 1 ]]; then api_configure proxmox proxmox; return; fi
            API_REPLACEMENTS=(
                ['<proxmox-host>']="$PROXMOX_HOST" ['<proxmox-port>']=443
                ['<user@realm!token-id=token-secret>']="$PROXMOX_API_TOKEN"
                ['<vm-storage>']=local-lvm ['<iso-storage>']=local
            )
            api_initialize proxmox proxmox
            printf 'Existing files were preserved; reconcile their host and token manually if they differ.\n'
            api_placeholders
            for file in "$API_CONFIG_ROOT/local/proxmox"/*.conf; do api_check_complete "$file"; done
            api_toggle proxmox ;;
        *) api_die 'Unknown API configuration command.' ;;
    esac
)

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then api_config_main "$@"; fi
