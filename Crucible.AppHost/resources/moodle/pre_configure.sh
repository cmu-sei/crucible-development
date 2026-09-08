#!/bin/sh
# Alpine default shell: ash

# Set moodle install root
BASE="/var/www/html"

# Moodle 5.1+ moved everything web-accessible under public/. admin/cli stays
# outside the web root in both layouts.
WEBROOT="$BASE"
if [ -d "$BASE/public" ]; then
    WEBROOT="$BASE/public"
fi

# Emulate array with space-separated values
MOUNTPATHS="$WEBROOT/theme $WEBROOT/lib $BASE/admin/cli $WEBROOT/ai/provider $WEBROOT/ai/classes"

for MOUNTPATH in $MOUNTPATHS; do
    # /moodle holds the seed copies without the public/ prefix, so strip whichever
    # root this path lives under.
    RELATIVE_PATH="${MOUNTPATH#$WEBROOT/}"
    RELATIVE_PATH="${RELATIVE_PATH#$BASE/}"
    # check for emtpy mount
    if [ ! -d "$MOUNTPATH" ] || [ -z "$(ls -A "$MOUNTPATH")" ]; then
        echo "$MOUNTPATH is empty, copying files";
        PARENT_DIR=$(dirname "$MOUNTPATH")
        mkdir -p "$PARENT_DIR"
        cp -r /moodle/$RELATIVE_PATH "$PARENT_DIR"
    else
        echo "$MOUNTPATH is not empty, persisting files";
    fi
done
