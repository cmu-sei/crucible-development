#!/bin/bash
# Copyright 2026 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.
#
# Rebuild custom Docker images for Crucible services
# Usage: ./scripts/rebuild-image.sh [moodle|misp|misp-modules|superset|all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

rebuild_moodle() {
    echo "Building moodle-custom:local..."
    docker build -t moodle-custom:local \
        -f "$PROJECT_ROOT/Crucible.AppHost/resources/moodle/Dockerfile.MoodleCustom" \
        "$PROJECT_ROOT/Crucible.AppHost/resources/moodle"
    echo "✓ moodle-custom:local built successfully"
}

rebuild_misp() {
    echo "Building misp-custom:local..."
    docker build -t misp-custom:local \
        -f "$PROJECT_ROOT/Crucible.AppHost/resources/misp/Dockerfile.MispCustom" \
        "$PROJECT_ROOT/Crucible.AppHost/resources/misp"
    echo "✓ misp-custom:local built successfully"
}

rebuild_misp_modules() {
    echo "Building misp-modules-custom:local..."
    docker build -t misp-modules-custom:local \
        -f "$PROJECT_ROOT/Crucible.AppHost/resources/misp/Dockerfile.MispModules" \
        "$PROJECT_ROOT/Crucible.AppHost/resources/misp"
    echo "✓ misp-modules-custom:local built successfully"
}

rebuild_superset() {
    echo "Building superset-custom:local..."
    docker build -t superset-custom:local \
        -f "$PROJECT_ROOT/Crucible.AppHost/resources/superset/Dockerfile.SupersetCustom" \
        "$PROJECT_ROOT/Crucible.AppHost/resources/superset"
    echo "✓ superset-custom:local built successfully"
}

case "$1" in
    moodle)
        rebuild_moodle
        ;;
    misp)
        rebuild_misp
        ;;
    misp-modules)
        rebuild_misp_modules
        ;;
    superset)
        rebuild_superset
        ;;
    all)
        rebuild_moodle
        rebuild_misp
        rebuild_misp_modules
        rebuild_superset
        echo ""
        echo "✓ All custom images built successfully"
        ;;
    *)
        echo "Usage: $0 [moodle|misp|misp-modules|superset|all]"
        echo ""
        echo "Rebuild custom Docker images for Crucible services:"
        echo "  moodle        - Rebuild moodle-custom:local"
        echo "  misp          - Rebuild misp-custom:local"
        echo "  misp-modules  - Rebuild misp-modules-custom:local"
        echo "  superset      - Rebuild superset-custom:local"
        echo "  all           - Rebuild all custom images"
        exit 1
        ;;
esac
