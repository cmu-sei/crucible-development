#!/bin/sh
# Copyright 2026 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

# Setup cron job to sync admin@localhost to site admins list

# Create cron job entry (runs every minute)
CRON_JOB="* * * * * /usr/local/bin/sync-site-admins.sh"

# Add to nobody's crontab (the user Moodle runs as)
echo "Setting up admin sync cron job..."

# Check if cron job already exists
if ! crontab -u nobody -l 2>/dev/null | grep -q "sync-site-admins.sh"; then
    # Get existing crontab or empty
    (crontab -u nobody -l 2>/dev/null || true; echo "$CRON_JOB") | crontab -u nobody -
    echo "Admin sync cron job installed successfully"
else
    echo "Admin sync cron job already exists"
fi

# Ensure crond is running (if not already started by base image)
if ! pgrep crond > /dev/null; then
    echo "Starting crond..."
    crond
fi
