<?php
// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.
//
// Idempotently ensure the demo course contains a configured mod_crucible lab.
//
// mod_crucible is not seeded by create_demo_activities.php because its one
// mandatory setting, eventtemplateid, is a GUID owned by Alloy - there is nothing
// sensible to hardcode. So ask Alloy which event templates exist and point the
// activity at one of them. Best effort throughout: a missing plugin, an Alloy
// that is down, and an Alloy with no event templates yet all just log and exit 0,
// because the dev stack is routinely brought up with only some services enabled.
//
// The activity is matched by its event template, so editing the text below will
// not update one that already exists; delete it in the course and re-run.

define('CLI_SCRIPT', true);
require('/var/www/html/config.php');
require_once($CFG->libdir . '/clilib.php');
require_once($CFG->libdir . '/filelib.php');
require_once($CFG->dirroot . '/course/modlib.php');
require_once('/usr/local/bin/lab_activity_lib.php');

list($options, $unrecognized) = cli_get_params(
    [
        'help' => false,
        'course' => 'Test Course',
        'name' => 'Demo Crucible Lab',
        'eventtemplate' => '',
    ],
    ['h' => 'help']
);

if ($options['help']) {
    echo "Ensure a configured Crucible (Alloy) lab activity exists in a course.\n";
    echo "  --course=<fullname>      Target course full name (default: 'Test Course')\n";
    echo "  --name=<name>            mod_crucible activity name\n";
    echo "  --eventtemplate=<name>   Preferred Alloy event template name, else the first one\n";
    exit(0);
}

$course = $DB->get_record('course', ['fullname' => $options['course']]);
if (!$course) {
    cli_error("Course '{$options['course']}' not found. (create_course should run first.)");
}

if (!$DB->record_exists('modules', ['name' => 'crucible'])) {
    cli_writeln("  mod_crucible is not installed - skipping '{$options['name']}'.");
    exit(0);
}

require_once($CFG->dirroot . '/mod/crucible/lib.php');

// add_moduleinfo() fires events and writes a grade item, both of which expect a
// real user.
\core\session\manager::set_user(get_admin());

$templates = null;
$token = lab_service_token('crucible');
if ($token) {
    $templates = lab_get_list(get_config('crucible', 'alloyapiurl') . '/eventtemplates', $token);
}

$template = is_array($templates) ? lab_pick_item($templates, $options['eventtemplate']) : null;
if (!$template) {
    cli_writeln('  No Alloy event template available - skipping the Crucible lab.');
    exit(0);
}

cli_writeln("  Using Alloy event template '{$template->name}' ({$template->id}).");

lab_create_activity($course, 'crucible', $options['name'], [
    'intro' => '<p>Seeded demo lab. Launches the <em>' . s($template->name) .
        '</em> event template in Alloy and shows its VMs and tasks in this activity.</p>',
    'eventtemplateid' => $template->id,
    // The values the add form would have supplied.
    'vmapp' => (int)get_config('crucible', 'vmapp'),
    'clock' => 1,
    'extendevent' => 0,
    'showcontentlicense' => 0,
    'grade' => 100,
    'grademethod' => \mod_crucible\utils\scaletypes::CRUCIBLE_HIGHESTATTEMPTGRADE,
], [
    // Not the name: mod/crucible/view.php overwrites the activity name with the
    // Alloy event template's name every time anyone opens the activity, so the
    // name seeded above survives only until the first view. Matching on it made
    // this script add another copy of the same lab on every run. The event
    // template is what the activity actually is, so match on that instead.
    'eventtemplateid' => $template->id,
]);
