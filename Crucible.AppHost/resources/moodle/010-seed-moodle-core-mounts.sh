#!/bin/sh

# Entry-point scripts run in lexical order. Seed the mounted Moodle core
# directories before 015-copy-plugins.sh installs Boost Union into theme/.
exec /usr/local/bin/pre_configure.sh
