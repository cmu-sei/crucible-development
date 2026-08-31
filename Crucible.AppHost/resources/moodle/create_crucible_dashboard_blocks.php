<?php
// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.
//
// Idempotently ensure the default dashboard contains the standard Crucible block views.

define('CLI_SCRIPT', true);
require('/var/www/html/config.php');
require_once($CFG->libdir . '/clilib.php');
require_once($CFG->libdir . '/blocklib.php');
require_once($CFG->dirroot . '/my/lib.php');

if (!$DB->record_exists('block', ['name' => 'crucible'])) {
    cli_error('block_crucible is not installed.');
}

$defaultpage = my_get_page(null, MY_PAGE_PRIVATE, MY_PAGE_DEFAULT);
if (!$defaultpage) {
    cli_error('The default dashboard page could not be found.');
}

$context = context_system::instance();
$instances = $DB->get_records('block_instances', [
    'blockname' => 'crucible',
    'parentcontextid' => $context->id,
    'pagetypepattern' => 'my-index',
    'subpagepattern' => $defaultpage->id,
]);

$existingviews = [];
foreach ($instances as $instance) {
    $config = unserialize(base64_decode($instance->configdata), ['allowed_classes' => [stdClass::class]]);
    if (empty($config->viewtype)) {
        continue;
    }

    $existingviews[$config->viewtype] = $instance;
}

$views = [
    ['viewtype' => 'learningplan', 'title' => 'My Learning Plans', 'showheader' => 1],
    ['viewtype' => 'competencies', 'title' => '', 'showheader' => 0],
    ['viewtype' => 'reports', 'title' => '', 'showheader' => 0],
    ['viewtype' => 'apps', 'title' => '', 'showheader' => 0],
];

foreach ($views as $offset => $view) {
    if (isset($existingviews[$view['viewtype']])) {
        cli_writeln("Crucible {$view['viewtype']} dashboard block already exists. Nothing to do.");
        continue;
    }

    $config = (object) [
        'title' => $view['title'],
        'showheader' => $view['showheader'],
        'viewtype' => $view['viewtype'],
    ];
    $instance = (object) [
        'blockname' => 'crucible',
        'parentcontextid' => $context->id,
        'showinsubcontexts' => 0,
        'pagetypepattern' => 'my-index',
        'subpagepattern' => $defaultpage->id,
        'defaultregion' => 'content',
        'defaultweight' => $offset + 2,
        'configdata' => base64_encode(serialize($config)),
        'timecreated' => time(),
        'timemodified' => time(),
    ];
    $instance->id = $DB->insert_record('block_instances', $instance);
    context_block::instance($instance->id);

    $block = block_instance('crucible', $instance);
    if ($block) {
        $block->instance_create();
    }

    cli_writeln("Created Crucible {$view['viewtype']} dashboard block (ID {$instance->id}).");
}
