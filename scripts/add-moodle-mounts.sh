#!/bin/bash

if [ -n "${CRUCIBLE_CI_SKIP_CLONE:-}" ]; then
  echo "CRUCIBLE_CI_SKIP_CLONE set; skipping moodle mount setup."
  exit 0
fi

# Define an array of directories
DIRS=(
    "/mnt/data/crucible/moodle/moodle-core/"
    "/mnt/data/crucible/moodle/moodle-core/theme"
    "/mnt/data/crucible/moodle/moodle-core/lib"
    "/mnt/data/crucible/moodle/moodle-core/admin/cli"
    "/mnt/data/crucible/moodle/moodle-core/ai/provider"
    "/mnt/data/crucible/moodle/moodle-core/ai/classes"
)

# Loop through the array to create directories and set permissions
for DIR in "${DIRS[@]}"; do
    mkdir -p "$DIR"
    chmod 777 "$DIR"
done
