#!/bin/bash
# Copyright 2026 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.
#
# Migrates Moodle plugins from flat structure to hierarchical structure
# Run this once if you have an existing dev environment with the old flat structure
#
# NOTE: This is a one-time migration script for the February 2026 restructuring.
# It can be removed once all developers have migrated to the hierarchical structure.

set -euo pipefail

echo "==================================================="
echo "Moodle Plugin Structure Migration"
echo "==================================================="
echo ""
echo "This script will:"
echo "1. Remove old flat plugin directories (mod_*, tool_*, etc.)"
echo "2. Preserve the new hierarchical structure (mod/*, admin/tool/*, etc.)"
echo "3. Preserve moodle-core directory"
echo ""
echo "Old flat structure example:"
echo "  /mnt/data/crucible/moodle/mod_topomojo/"
echo ""
echo "New hierarchical structure example:"
echo "  /mnt/data/crucible/moodle/mod/topomojo/"
echo ""
read -p "Continue with migration? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Migration cancelled."
    exit 0
fi

MOODLE_DIR="/mnt/data/crucible/moodle"

if [ ! -d "$MOODLE_DIR" ]; then
    echo "Error: $MOODLE_DIR does not exist"
    exit 1
fi

cd "$MOODLE_DIR"

echo ""
echo "Removing old flat plugin directories..."

# Array of patterns to remove
PATTERNS=(
    "mod_*"
    "block_*"
    "tool_*"
    "logstore_*"
    "local_*"
    "qtype_*"
    "qbehaviour_*"
    "aiplacement_*"
    "theme_*"
    "qformat_*"
)

for pattern in "${PATTERNS[@]}"; do
    # Find directories matching the pattern
    for dir in $pattern; do
        # Check if it's a directory and exists (not just the glob pattern)
        if [ -d "$dir" ]; then
            echo "  Removing: $dir"
            rm -rf "$dir"
        fi
    done
done

echo ""
echo "==================================================="
echo "Migration complete!"
echo "==================================================="
echo ""
echo "The hierarchical structure is now in place:"
ls -l "$MOODLE_DIR" | grep "^d" | grep -v "moodle-core" | awk '{print "  " $NF}'
echo ""
echo "Next steps:"
echo "1. Rebuild your devcontainer or restart Docker containers"
echo "2. Verify plugins are working correctly"
echo ""
