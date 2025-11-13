<?php

// Set coverage for just our repos
$includePaths[] = "/var/www/html/mod/crucible";
$includePaths[] = "/var/www/html/mod/topomojo";
$includePaths[] = "/var/www/html/mod/groupquiz";
$includePaths[] = "/var/www/html/blocks/crucible";
$includePaths[] = "/var/www/html/admin/tool/lptmanager";
$includePaths[] = "/var/www/html/question/type/mojomatch";
$includePaths[] = "/var/www/html/question/behaviour/mojomatch";
$includePaths[] = "/var/www/html/ai/placement/classifyassist";

if (extension_loaded(extension: 'xdebug') && !empty($includePaths)) {
    xdebug_set_filter(
        XDEBUG_FILTER_CODE_COVERAGE,
        XDEBUG_PATH_INCLUDE,
        $includePaths
    );
}
?>
