<?php

// Set coverage for just our repos
$includePaths = [
    "/var/www/html/mod/crucible",
    "/var/www/html/mod/topomojo",
    "/var/www/html/mod/groupquiz",
    "/var/www/html/blocks/crucible",
    "/var/www/html/admin/tool/lptmanager",
    "/var/www/html/question/type/mojomatch",
    "/var/www/html/question/behaviour/mojomatch"
];

if (extension_loaded('xdebug') && !empty($includePaths)) {
    xdebug_set_filter(
        XDEBUG_FILTER_CODE_COVERAGE, // is a metric used to measure the percentage of code that is executed during testing
        XDEBUG_PATH_INCLUDE,
        $includePaths
    );
}
?>
