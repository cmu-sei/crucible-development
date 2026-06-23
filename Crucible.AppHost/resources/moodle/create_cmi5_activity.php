<?php
// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.
//
// Idempotently ensure a target course has a cmi5launch activity backed by a course
// that actually exists on the CATAPULT player.
//
// Why this exists: the CATAPULT player stores imported course *content* on its
// container filesystem (var/content), which is wiped whenever the player image is
// rebuilt, while Moodle's activity record and the player's DB row may persist. That
// desync produces a 404 ("Not Found") on launch. Re-importing the package through the
// plugin's normal add_instance path repopulates the player and rewires Moodle's record.
//
// Behavior (intended to run only when CATAPULT is enabled):
//   - If the target course has no cmi5launch activity -> create one from the bundled package.
//   - If it has one but the player no longer serves that course -> recreate it.
//   - Otherwise -> no-op.
//
// The bundled package (sample_cmi5_geology.zip) is the Apache-2.0 licensed
// "single_au_basic_framed" example from adlnet/CATAPULT (course_examples),
// (c) 2021 Rustici Software. See that repository's LICENSE for terms.
//
// Usage:
//   php create_cmi5_activity.php --course="Test Course" --package=/usr/local/share/cmi5/sample_cmi5.zip --name="Geology Intro (cmi5)"

define('CLI_SCRIPT', true);
require('/var/www/html/config.php');
require_once($CFG->libdir . '/clilib.php');
require_once($CFG->dirroot . '/course/modlib.php');
require_once($CFG->dirroot . '/mod/cmi5launch/lib.php');
require_once($CFG->dirroot . '/mod/cmi5launch/classes/local/cmi5_connectors.php');

list($options, $unrecognized) = cli_get_params(
    [
        'help'    => false,
        'course'  => 'Test Course',
        'package' => '/usr/local/share/cmi5/sample_cmi5.zip',
        'name'    => 'Geology Intro (cmi5)',
    ],
    ['h' => 'help']
);

if ($options['help']) {
    echo "Ensure a cmi5launch activity exists in a course and is backed by live player content.\n";
    echo "  --course=<fullname>   Target course full name (default: 'Test Course')\n";
    echo "  --package=<path>      Path to the cmi5 .zip package\n";
    echo "  --name=<activityname> Name for the cmi5launch activity\n";
    exit(0);
}

$coursename = $options['course'];
$packagepath = $options['package'];
$activityname = $options['name'];

// ---- Locate the target course -------------------------------------------------
$course = $DB->get_record('course', ['fullname' => $coursename]);
if (!$course) {
    cli_error("Course '{$coursename}' not found. (create_course should run first.)");
}

if (!file_exists($packagepath)) {
    cli_error("cmi5 package not found at '{$packagepath}'.");
}

// ---- Helper: is a Moodle cmi5launch record still served by the player? --------
// Mints a tenant token and asks the player for the course; returns true only if the
// player currently knows about the course id stored on the Moodle record.
function cmi5_player_has_course(int $playercourseid): bool {
    global $CFG;

    $playerurl = trim((string) get_config('cmi5launch', 'cmi5launchplayerurl'));
    $basicname = (string) get_config('cmi5launch', 'cmi5launchbasicname');
    $basicpass = (string) get_config('cmi5launch', 'cmi5launchbasepass');
    if ($playerurl === '' || $playercourseid <= 0) {
        return false;
    }

    // Mint a token for the first tenant (id 1, created at player startup).
    $authch = curl_init($playerurl . '/api/v1/auth');
    curl_setopt_array($authch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST           => true,
        CURLOPT_USERPWD        => $basicname . ':' . $basicpass,
        CURLOPT_HTTPHEADER     => ['Content-Type: application/json'],
        CURLOPT_POSTFIELDS     => json_encode(['tenantId' => 1, 'audience' => 'crucible']),
        CURLOPT_TIMEOUT        => 15,
    ]);
    $authresp = curl_exec($authch);
    $authcode = curl_getinfo($authch, CURLINFO_HTTP_CODE);
    curl_close($authch);
    if ($authcode !== 200) {
        return false;
    }
    $token = json_decode($authresp, true)['token'] ?? '';
    if ($token === '') {
        return false;
    }

    // Ask the player for that specific course.
    $ch = curl_init($playerurl . '/api/v1/course/' . $playercourseid);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER     => ['Authorization: Bearer ' . $token],
        CURLOPT_TIMEOUT        => 15,
    ]);
    curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    return $code === 200;
}

// ---- Check for an existing, healthy cmi5launch activity in the course ---------
$existing = $DB->get_records('cmi5launch', ['course' => $course->id]);
foreach ($existing as $rec) {
    $playercourseid = (int) ($rec->courseid ?? 0);
    if ($playercourseid > 0 && cmi5_player_has_course($playercourseid)) {
        cli_writeln("cmi5launch activity '{$rec->name}' already exists and is served by the player (course id {$playercourseid}). Nothing to do.");
        exit(0);
    }
    cli_writeln("Found stale cmi5launch activity '{$rec->name}' (player course id "
        . $playercourseid . " missing); it will be replaced.");
    // Remove the stale course module so we can recreate cleanly.
    if ($cm = get_coursemodule_from_instance('cmi5launch', $rec->id, $course->id)) {
        course_delete_module($cm->id);
        cli_writeln("  Removed stale course module {$cm->id}.");
    } else {
        $DB->delete_records('cmi5launch', ['id' => $rec->id]);
    }
}

// ---- Build a draft file area containing the package ---------------------------
// add_instance reads $cmi5launch->packagefile as a draft itemid; stage the zip there.
$admin = get_admin();
\core\session\manager::set_user($admin);

$usercontext = context_user::instance($admin->id);
$fs = get_file_storage();
$draftitemid = file_get_unused_draft_itemid();

$filerecord = [
    'contextid' => $usercontext->id,
    'component' => 'user',
    'filearea'  => 'draft',
    'itemid'    => $draftitemid,
    'filepath'  => '/',
    'filename'  => basename($packagepath),
];
$fs->create_file_from_pathname($filerecord, $packagepath);

// ---- Assemble the module info and create the activity via the core path -------
$cmi5config = get_config('cmi5launch');

$moduleinfo = new stdClass();
$moduleinfo->modulename     = 'cmi5launch';
$moduleinfo->course         = $course->id;
$moduleinfo->section        = 0;
$moduleinfo->visible        = 1;
$moduleinfo->name           = $activityname;
$moduleinfo->intro          = '';
$moduleinfo->introformat    = FORMAT_HTML;
$moduleinfo->packagefile    = $draftitemid;
// Inherit the site-level cmi5launch defaults (LRS, actor homepage, etc.).
$moduleinfo->cmi5launchcustomacchp = $cmi5config->cmi5launchcustomacchp ?? '';
$moduleinfo->cmi5multipleregs = 1;
$moduleinfo->overridedefaults = 0;

$module = $DB->get_record('modules', ['name' => 'cmi5launch'], '*', MUST_EXIST);
$moduleinfo->module = $module->id;

try {
    $created = add_moduleinfo($moduleinfo, $course);
    cli_writeln("Created cmi5launch activity '{$activityname}' (cmid {$created->coursemodule}) in '{$coursename}'.");
} catch (\Throwable $e) {
    cli_error("Failed to create cmi5launch activity: " . $e->getMessage());
}

exit(0);
