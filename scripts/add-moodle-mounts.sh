#!/bin/bash

# Define an array of directories
DIRS=(
    "/mnt/data/crucible/moodle/moodle-core/"
    "/mnt/data/crucible/moodle/moodle-core/theme"
    "/mnt/data/crucible/moodle/moodle-core/lib"
    "/mnt/data/crucible/moodle/moodle-core/admin/cli"
)

# Loop through the array to create directories and set permissions
for DIR in "${DIRS[@]}"; do
    mkdir -p "$DIR"
    chmod 777 "$DIR"
done
