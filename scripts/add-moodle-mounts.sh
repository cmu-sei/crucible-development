#!/bin/bash

if [ -n "${CRUCIBLE_CI_SKIP_CLONE:-}" ]; then
  echo "CRUCIBLE_CI_SKIP_CLONE set; skipping moodle mount setup."
  exit 0
fi

# One mount root per Moodle version Aspire can run (see AddMoodle in AppHost.cs).
# Each version needs its own root: sharing them would let one version's code end up
# under another's.
ROOTS=(
    "/mnt/data/crucible/moodle/moodle-core"
    "/mnt/data/crucible/moodle/moodle-core-52"
)

# Bind-mounted core directories, relative to a root. The host layout stays flat even
# though Moodle 5.1+ serves these from public/ inside the container.
SUBDIRS=(
    ""
    "theme"
    "lib"
    "admin/cli"
    "ai/provider"
    "ai/classes"
)

# Create the directories and make them world-writable: the Moodle container runs as
# nobody (65534) and pre_configure.sh seeds these mounts on first boot.
for ROOT in "${ROOTS[@]}"; do
    for SUBDIR in "${SUBDIRS[@]}"; do
        DIR="${ROOT}${SUBDIR:+/$SUBDIR}"
        mkdir -p "$DIR"
        chmod 777 "$DIR"
    done
done
