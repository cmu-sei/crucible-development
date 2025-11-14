#!/bin/sh
# Alpine default shell: ash

# Set moodle web root
BASE="/var/www/html"

# Emulate array with space-separated values
MOUNTPATHS="/var/www/html/theme /var/www/html/lib /var/www/html/admin/cli"

for MOUNTPATH in $MOUNTPATHS; do
    RELATIVE_PATH="${MOUNTPATH#$BASE/}"
    # check for emtpy mount
    if [ -z "$(ls -A "$MOUNTPATH")" ]; then
        echo "$MOUNTPATH is empty, copying files";
        PARENT_DIR=$(dirname "$MOUNTPATH")
        cp -r /moodle/$RELATIVE_PATH "$PARENT_DIR"
    else
        echo "$MOUNTPATH is not empty, persisting files";
    fi
done
