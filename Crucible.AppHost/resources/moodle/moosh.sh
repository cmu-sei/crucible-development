#!/usr/bin/env php

# this script is used to set the user-agent header and is copied from alpine-moodle at:
# https://github.com/erseco/alpine-moodle/blob/main/rootfs/usr/local/bin/moosh

<?php
putenv('HOME=/tmp');
chdir('/opt/moosh');

// Set a user agent to avoid 403 errors from Moodle.org (Cloudflare block)
ini_set('user_agent', 'curl/7.81.0');

// Optional: force the user agent in all HTTP contexts
stream_context_set_default([
    'http' => [
        'user_agent' => 'curl/7.81.0'
    ]
]);

// Separate global options and the subcommand
$script = array_shift($argv);

// Check if a Moodle path was provided
$hasMoodlePath = false;
foreach ($argv as $arg) {
    if (strpos($arg, '-p') === 0 || strpos($arg, '--moodle-path') === 0) {
        $hasMoodlePath = true;
        break;
    }
}

// Insert -p /var/www/html before the first non-option argument (the subcommand)
if (!$hasMoodlePath) {
    $insertAt = 0;
    foreach ($argv as $i => $arg) {
        if ($arg[0] !== '-') {
            $insertAt = $i;
            break;
        }
    }
    array_splice($argv, $insertAt, 0, ['-p', '/var/www/html', '-o', 'session_handler_class=unset']);
}

array_unshift($argv, $script);
require '/opt/moosh/moosh.php';
