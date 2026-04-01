#!/bin/sh
# Copyright 2026 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

# Sync admin@localhost user to site admins list
# This ensures the OAuth2 admin user always has site admin privileges

cd /var/www/html

# Find admin@localhost user ID
ADMINUSERID=$(moosh user-list 2>/dev/null | grep admin@localhost | sed -e "s/admin.*(\([0-9]*\)).*/\1/")

if [ -n "$ADMINUSERID" ]; then
    # Get current site admins list
    CURRENT_ADMINS=$(php admin/cli/cfg.php --name=siteadmins 2>/dev/null)

    # Check if admin user is already in the list
    if ! echo "$CURRENT_ADMINS" | grep -q "$ADMINUSERID"; then
        # Add admin user to site admins (2 is the default admin, keep it)
        php admin/cli/cfg.php --name=siteadmins --set="2,$ADMINUSERID" 2>/dev/null
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Added admin@localhost (ID: $ADMINUSERID) to site admins list" >> /tmp/sync-admins.log
    fi
fi
