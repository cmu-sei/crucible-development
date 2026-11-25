#!/bin/bash
# Copyright 2026 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.
#
# Checks how pre_configure.sh seeds a Moodle instance's bind-mounted core folders: an empty folder is seeded and
# marked with the image, a folder seeded from the same image is left alone, and one seeded from another image
# (or before the marker existed) is copied to the backup folder and seeded again. Runs the real script in a
# throwaway container with a fake /moodle seed tree, so it touches none of the running Moodle instances.
#
# Usage: tests/moodle-core-mounts.sh [image]    (default: any Moodle dev image already pulled)

set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/Crucible.AppHost/resources/moodle/pre_configure.sh"
IMAGE="${1:-erseco/alpine-moodle:v5.2.5}"

docker image inspect "$IMAGE" >/dev/null 2>&1 || { echo "Image $IMAGE is not pulled; pass one that is." >&2; exit 2; }

# Everything below runs inside the container, as root, against a fixture.
docker run --rm --user root --entrypoint sh -v "$SCRIPT:/pre_configure.sh:ro" "$IMAGE" -c '
set -u
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   - $1"; else echo "FAIL - $1 (expected [$3], got [$2])"; fail=1; fi; }

WEB=/var/www/html/public
reset_world() {
    rm -rf /moodle /moodle-previous /var/www/html/public /var/www/html/admin
    mkdir -p /moodle/theme /moodle/lib /moodle/admin/cli /moodle/ai/provider /moodle/ai/classes /moodle-previous
    for d in theme lib admin/cli ai/provider ai/classes; do echo "seed $1" > /moodle/$d/file.txt; done
    printf "%s\n" "$1" > /moodle/.image
    mkdir -p $WEB/theme $WEB/lib $WEB/ai/provider $WEB/ai/classes /var/www/html/admin/cli
}
run() { sh /pre_configure.sh >/tmp/out.txt 2>&1; }

reset_world image-A
run
check "an empty mount is seeded" "$(cat $WEB/theme/file.txt)" "seed image-A"
check "and marked with the image" "$(cat $WEB/theme/.crucible-image)" "image-A"

echo "my edit" > $WEB/theme/file.txt
run
check "a mount seeded from the same image is left alone" "$(cat $WEB/theme/file.txt)" "my edit"
check "and nothing is moved aside" "$(ls /moodle-previous | wc -l | tr -d " ")" "0"

reset_world image-B
mkdir -p $WEB/theme && echo "old edit" > $WEB/theme/file.txt && echo "image-A" > $WEB/theme/.crucible-image
run
check "a mount seeded from another image is seeded again" "$(cat $WEB/theme/file.txt)" "seed image-B"
check "and marked with the new image" "$(cat $WEB/theme/.crucible-image)" "image-B"
check "after the old contents are kept" "$(cat /moodle-previous/theme-from-image-A/file.txt)" "old edit"

reset_world image-C
echo "pre marker edit" > $WEB/lib/file.txt
run
check "a mount with no marker counts as stale" "$(cat $WEB/lib/file.txt)" "seed image-C"
check "and its contents are kept" "$(cat /moodle-previous/lib-from-unknown/file.txt)" "pre marker edit"

reset_world image-D
echo "stays put" > $WEB/theme/file.txt; echo "image-X" > $WEB/theme/.crucible-image
rm -rf /moodle-previous
run
check "with nowhere to keep the old contents, a stale mount is left as it is" "$(cat $WEB/theme/file.txt)" "stays put"
check "and the script says why" "$(grep -c "is not writable" /tmp/out.txt | tr -d " ")" "1"

exit $fail
'
