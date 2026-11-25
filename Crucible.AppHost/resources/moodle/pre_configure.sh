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

# Where the seed copies in /moodle came from, and where a stale mount is moved aside to. The marker in each mount
# says which image it was seeded from: a bind mount is only ever seeded when empty, so without it a new image would
# run on the previous image's core code, lib/db/upgrade.php included, and the database upgrade would skip steps.
IMAGE_FILE="/moodle/.image"
MARKER=".crucible-image"
BACKUP_ROOT="${CORE_BACKUP_ROOT:-/moodle-previous}"
CURRENT_IMAGE="$(cat "$IMAGE_FILE" 2>/dev/null)"

# Emulate array with space-separated values
MOUNTPATHS="$WEBROOT/theme $WEBROOT/lib $BASE/admin/cli $WEBROOT/ai/provider $WEBROOT/ai/classes"

for MOUNTPATH in $MOUNTPATHS; do
    # /moodle holds the seed copies without the public/ prefix, so strip whichever
    # root this path lives under.
    RELATIVE_PATH="${MOUNTPATH#$WEBROOT/}"
    RELATIVE_PATH="${RELATIVE_PATH#$BASE/}"
    # A mount seeded from another image, or from before this check existed, is moved aside and seeded again.
    if [ -n "$CURRENT_IMAGE" ] && [ -d "$MOUNTPATH" ] && [ -n "$(ls -A "$MOUNTPATH")" ]; then
        SEEDED_FROM="$(cat "$MOUNTPATH/$MARKER" 2>/dev/null)"
        if [ "$SEEDED_FROM" != "$CURRENT_IMAGE" ]; then
            SAFE_NAME="$(echo "$RELATIVE_PATH" | tr / _)"
            SAFE_FROM="$(echo "${SEEDED_FROM:-unknown}" | tr '/:' '__')"
            BACKUP="$BACKUP_ROOT/$SAFE_NAME-from-$SAFE_FROM"
            # Nothing is deleted unless it has somewhere to go, so a developer's edits are never lost.
            if [ -d "$BACKUP_ROOT" ] && [ -w "$BACKUP_ROOT" ] && mkdir -p "$BACKUP" && cp -a "$MOUNTPATH/." "$BACKUP/"; then
                echo "$MOUNTPATH was seeded from ${SEEDED_FROM:-an unknown image}, not $CURRENT_IMAGE: kept a copy in $BACKUP and seeding again";
                find "$MOUNTPATH" -mindepth 1 -delete
            else
                echo "WARNING: $MOUNTPATH was seeded from ${SEEDED_FROM:-an unknown image}, not $CURRENT_IMAGE, but $BACKUP_ROOT is not writable, so it is left as it is. Move its contents aside by hand to seed it again." >&2
            fi
        fi
    fi

    # check for emtpy mount
    if [ ! -d "$MOUNTPATH" ] || [ -z "$(ls -A "$MOUNTPATH")" ]; then
        echo "$MOUNTPATH is empty, copying files";
        PARENT_DIR=$(dirname "$MOUNTPATH")
        mkdir -p "$PARENT_DIR"
        cp -r /moodle/$RELATIVE_PATH "$PARENT_DIR"
        # sed -i later in this boot needs a writable directory, not just a writable file.
        find "$MOUNTPATH" -type d -exec chmod a+rwx {} + 2>/dev/null || true
        if [ -n "$CURRENT_IMAGE" ]; then
            echo "$CURRENT_IMAGE" > "$MOUNTPATH/$MARKER"
            chmod a+rw "$MOUNTPATH/$MARKER" 2>/dev/null || true
        fi
    else
        echo "$MOUNTPATH is not empty, persisting files";
    fi
done
