#!/bin/bash
set -e

# Toggle local library debugging for EntityEvents dotnet library.
# Usage: toggle-local-library.sh [on|off|status]
#   on     - Enable local library debugging (Project Reference)
#   off    - Disable local library debugging (NuGet)
#   status - Show current state
#   (no args) - Toggle current value

OVERRIDE_FILE="/mnt/data/crucible/Directory.Build.props"

get_current_value() {
    if [[ -f "$OVERRIDE_FILE" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

enable() {
    if [[ -f "$OVERRIDE_FILE" ]]; then
        echo "Local library debugging: already ON"
        return
    fi

    # Create minimal override file that imports parent and overrides property
    cat > "$OVERRIDE_FILE" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<Project>
  <!-- Import parent Directory.Build.props -->
  <Import Project="../Directory.Build.props" />

  <PropertyGroup>
    <!-- Override to enable local library debugging -->
    <UseLocalEntityEvents>true</UseLocalEntityEvents>
  </PropertyGroup>
</Project>
EOF

    echo "Local library debugging: ON"
}

disable() {
    if [[ ! -f "$OVERRIDE_FILE" ]]; then
        echo "Local library debugging: already OFF"
        return
    fi

    rm "$OVERRIDE_FILE"
    echo "Local library debugging: OFF"
}

show_status() {
    local current=$(get_current_value)
    if [[ "$current" == "true" ]]; then
        echo "Local library debugging: ON (using local EntityEvents source)"
        echo "Override file: $OVERRIDE_FILE"
    else
        echo "Local library debugging: OFF (using NuGet packages)"
        echo "Override file: not created (using parent defaults)"
    fi
}

case "${1:-}" in
    on)
        enable
        ;;
    off)
        disable
        ;;
    status)
        show_status
        ;;
    "")
        # Toggle
        current=$(get_current_value)
        if [[ "$current" == "true" ]]; then
            disable
        else
            enable
        fi
        ;;
    *)
        echo "Usage: $0 [on|off|status]"
        echo "  on     - Enable local library debugging"
        echo "  off    - Disable local library debugging"
        echo "  status - Show current state"
        echo "  (no args) - Toggle current value"
        exit 1
        ;;
esac
