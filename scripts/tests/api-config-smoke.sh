#!/usr/bin/env bash
# Four safety checks, using isolated fixtures and dummy credentials. No test framework.
set -euo pipefail
umask 077
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
smoke_root=$(mktemp -d "${TMPDIR:-/tmp}/api-config-smoke.XXXXXX")
trap 'rm -rf -- "$smoke_root"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
equal() { [[ $1 == "$2" ]] || fail "$3"; }
fixture() {
    case_root=$(mktemp -d "$smoke_root/case.XXXXXX")
    app="$case_root/Crucible.AppHost"
    config="$app/resources/api/config"
    mkdir -p "$case_root/scripts" "$config"
    cp "$repo/scripts/"{api-config.sh,api-config.jq,configure-hypervisors.sh,toggle-hypervisor.sh} "$case_root/scripts/"
    cp -R "$repo/Crucible.AppHost/resources/api/config/templates" "$config/templates"
    printf '%s\n' '{"Launch":{"Dev":["Player","Caster","TopoMojo"]}}' > "$app/appsettings.json"
    # Exercise comments, trailing commas, literal URL/comment text, and key casing.
    printf '%s\n' '{ /* setup */ "launch":{"ApiConfig":{"Enabled":false,},},' \
        '"url":"https://test/*literal*/", "text":"escaped \"//text", "keep":false,}' > "$app/appsettings.Development.json"
    log="$case_root/output"
}
configure() { bash "$case_root/scripts/configure-hypervisors.sh" "$@"; }
toggle() { bash "$case_root/scripts/toggle-hypervisor.sh" "$@"; }
# Feed deterministic answers without needing a TTY. Production entry points still
# enforce a terminal; read -r/-s and the actual prompt/write functions are unchanged.
guided() {
    bash -c 'source "$1"; shift; api_terminal() { :; }; api_config_main configure "$@"' \
        -- "$case_root/scripts/api-config.sh" "$@"
}
conf_value() {
    local line
    while IFS= read -r line; do
        if [[ $line == "$2="* ]]; then printf '%s' "${line#*=}"; return; fi
    done < "$1"
    return 1
}
expect_failure() {
    if "$@" > "$log" 2>&1; then fail "Unexpected success: $*"; fi
}
setup_vsphere() {
    printf 'vc.test\n\nfake-password\n\nDC/Cluster/Parent/Pool\n' |
        guided vsphere --profile lab > "$log" 2>&1
}

# 1. Literal credentials, saved defaults and private files; nothing sensitive logged.
fixture
token='user@realm!id=$HOME&\literal`id`$(touch SHOULD_NOT_EXIST)=<literal>'
saved="$case_root/proxmox-config"
printf 'export PROXMOX_HOST=%q\nexport PROXMOX_API_TOKEN=%q\n' pve.test "$token" > "$saved"
printf '\n8006\n\nfast-vms\nisos\n' |
    PROXMOX_CONFIG_FILE="$saved" guided proxmox --profile lab > "$log" 2>&1
for entry in 'topomojo:Pod__AccessToken' 'player-vm-api:Proxmox__Token' \
    'caster-api:Terraform__EnvironmentVariables__Direct__PROXMOX_VE_API_TOKEN'; do
    equal "$(conf_value "$config/local/lab/${entry%%:*}.conf" "${entry#*:}")" "$token" 'Credential changed'
    equal "$(stat -c %a "$config/local/lab/${entry%%:*}.conf")" 600 'Config is not private'
done
equal "$(conf_value "$config/local/lab/topomojo.conf" Pod__Url)" https://pve.test:8006 'Host/port mismatch'
equal "$(stat -c %a "$config/local/lab")" 700 'Profile directory is not private'
if grep -Fq -- "$token" "$log" "$app/appsettings.Development.json"; then fail 'Credential was exposed'; fi
[[ ! -e SHOULD_NOT_EXIST ]] || fail 'Credential was executed'
jq -e '.launch.ApiConfig.Profile == "lab" and .keep == false and
    .url == "https://test/*literal*/" and .text == "escaped \"//text"' \
    "$app/appsettings.Development.json" >/dev/null
printf 'PASS: literal credentials and private output\n'

# 2. Keep, cancel, and EOF during regeneration cannot overwrite local edits.
fixture
setup_vsphere
printf 'Custom__Setting=keep\n' >> "$config/local/lab/topomojo.conf"
cp "$config/local/lab/topomojo.conf" "$case_root/original"
cp "$app/appsettings.Development.json" "$case_root/settings"
printf '\n' | guided vsphere --profile lab > "$log" 2>&1
printf 'cancel\n' | expect_failure guided vsphere --profile lab
printf 'regenerate\n' | expect_failure guided vsphere --profile lab
cmp -s "$case_root/original" "$config/local/lab/topomojo.conf" || fail 'Keep/cancel changed files'
cmp -s "$case_root/settings" "$app/appsettings.Development.json" || fail 'Cancel changed selection'
[[ -z $(find "$config/local/lab" -name '*.bak' -print) ]] || fail 'Cancel created backups'
printf 'PASS: keep and cancellation preserve files\n'

# 3. Regeneration backs up all originals and incorporates fixed template additions.
printf 'New__Setting=fixed\n' >> "$config/templates/vsphere/topomojo.conf.template"
printf 'regenerate\nnew.test\n\nnew-password\n\n\n' |
    guided vsphere --profile lab > "$log" 2>&1
backups=("$config/local/lab/"*.bak)
equal "${#backups[@]}" 3 'Expected three backups'
for backup in "${backups[@]}"; do equal "$(stat -c %a "$backup")" 600 'Backup is not private'; done
topo_backup=("$config/local/lab/topomojo.conf."*.bak)
cmp -s "$case_root/original" "${topo_backup[0]}" || fail 'Backup differs from original'
equal "$(conf_value "$config/local/lab/topomojo.conf" Pod__Url)" https://new.test/sdk 'Regeneration did not apply'
equal "$(conf_value "$config/local/lab/topomojo.conf" New__Setting)" fixed 'Fixed setting did not copy'
printf 'PASS: regeneration creates recoverable backups\n'

# 4. Bad profiles, malformed/unfilled files, and JSON errors leave selection unchanged.
fixture
setup_vsphere
cp "$app/appsettings.Development.json" "$case_root/settings"
expect_failure toggle ../escape
configure init proxmox --profile incomplete > "$log" 2>&1
expect_failure toggle incomplete
printf 'KEY=secret\nkey=other\n' > "$config/local/lab/caster-api.conf"
expect_failure toggle lab
if grep -q secret "$log"; then fail 'Validation printed a value'; fi
cmp -s "$case_root/settings" "$app/appsettings.Development.json" || fail 'Bad input changed selection'
printf 'invalid /* unterminated\n' > "$app/appsettings.Development.json"
cp "$app/appsettings.Development.json" "$case_root/invalid"
expect_failure toggle lab
cmp -s "$case_root/invalid" "$app/appsettings.Development.json" || fail 'Malformed JSON was overwritten'
printf 'PASS: invalid input leaves selection unchanged\n'
