<?php
// Copyright 2025 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

// Set coverage and debugging for just our repos and bind-mounted directories
$includePaths = [
    "/var/www/html/theme",
    "/var/www/html/lib",
    "/var/www/html/admin/cli",
    "/var/www/html/mod/crucible",
    "/var/www/html/mod/topomojo",
    "/var/www/html/mod/groupquiz",
    "/var/www/html/ai/placement/competency",
    "/var/www/html/blocks/crucible",
    "/var/www/html/admin/tool/lptmanager",
    "/var/www/html/local/tagmanager",
    "/var/www/html/admin/tool/userdebug",
    "/var/www/html/question/type/mojomatch",
    "/var/www/html/question/behaviour/mojomatch"
];

if (extension_loaded('xdebug') && !empty($includePaths)) {
    // Filter code coverage
    xdebug_set_filter(
        XDEBUG_FILTER_CODE_COVERAGE,
        XDEBUG_PATH_INCLUDE,
        $includePaths
    );

    // Filter tracing/debugging to prevent "Unknown sourceReference 0" errors
    // This limits step debugging to only the directories we have locally
    xdebug_set_filter(
        XDEBUG_FILTER_TRACING,
        XDEBUG_PATH_INCLUDE,
        $includePaths
    );
}
?>
