<?php
// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.
//
// Idempotently ensure the demo course contains a configured mod_topomojo lab.
//
// mod_topomojo is not seeded by create_demo_activities.php because its one
// mandatory setting, workspaceid, is a GUID owned by TopoMojo - there is nothing
// sensible to hardcode. So ask TopoMojo which workspaces exist and point the
// activity at one of them. Best effort throughout: a missing plugin, a TopoMojo
// that is down, and a TopoMojo with no workspaces yet all just log and exit 0,
// because the dev stack is routinely brought up with only some services enabled.
//
// The activity is matched by name, so editing the text below will not update one
// that already exists; delete it in the course and re-run.

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
        'name' => 'Demo TopoMojo Lab',
        'workspace' => '',
    ],
    ['h' => 'help']
);

if ($options['help']) {
    echo "Ensure a configured TopoMojo lab activity exists in a course.\n";
    echo "  --course=<fullname>   Target course full name (default: 'Test Course')\n";
    echo "  --name=<name>         mod_topomojo activity name\n";
    echo "  --workspace=<name>    Preferred TopoMojo workspace name, else the first one\n";
    exit(0);
}

$course = $DB->get_record('course', ['fullname' => $options['course']]);
if (!$course) {
    cli_error("Course '{$options['course']}' not found. (create_course should run first.)");
}

if (!$DB->record_exists('modules', ['name' => 'topomojo'])) {
    cli_writeln("  mod_topomojo is not installed - skipping '{$options['name']}'.");
    exit(0);
}

require_once($CFG->dirroot . '/mod/topomojo/lib.php');
require_once($CFG->dirroot . '/mod/topomojo/locallib.php');

// add_moduleinfo() fires events and writes a grade item, both of which expect a
// real user.
\core\session\manager::set_user(get_admin());

// setup() returns a curl client carrying whichever credential the site is
// configured for, API key or OAuth2, so reuse it rather than reimplementing that
// choice here.
$workspaces = null;
$client = setup();
if ($client) {
    $workspaces = get_workspaces($client);
}

$workspace = is_array($workspaces) ? lab_pick_item($workspaces, $options['workspace']) : null;
if (!$workspace) {
    cli_writeln('  No TopoMojo workspace available - skipping the TopoMojo lab.');
    exit(0);
}

cli_writeln("  Using TopoMojo workspace '{$workspace->name}' ({$workspace->id}).");

lab_create_activity($course, 'topomojo', $options['name'], [
    'intro' => '<p>Seeded demo lab. Deploys the <em>' . s($workspace->name) .
        '</em> workspace in TopoMojo and embeds its guide in this activity.</p>',
    'workspaceid' => $workspace->id,
    // The values the add form would have supplied. The review* columns are
    // bitfields that topomojo_process_options() builds out of the per-when
    // checkboxes, so "during the attempt" is expressed by setting those rather
    // than by writing the columns directly.
    'embed' => (int)get_config('topomojo', 'embed'),
    'clock' => 1,
    'extendevent' => 0,
    'extendinterval' => (int)get_config('topomojo', 'maxextendinterval'),
    'duration' => 3600,
    'variant' => 1,
    'attempts' => (int)get_config('topomojo', 'maxattempts'),
    'submissions' => 0,
    'importchallenge' => 1,
    'endlab' => 0,
    'isfeatured' => 0,
    'showcontentlicense' => 0,
    'shuffleanswers' => 0,
    'preferredbehaviour' => 'deferredfeedback',
    'grade' => 100,
    'grademethod' => \mod_topomojo\utils\scaletypes::TOPOMOJO_HIGHESTATTEMPTGRADE,
    'attemptduring' => 1,
    'correctnessduring' => 1,
    'marksduring' => 1,
    'specificfeedbackduring' => 1,
    'generalfeedbackduring' => 1,
    'rightanswerduring' => 1,
]);
