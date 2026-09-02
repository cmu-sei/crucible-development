<?php
// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.
//
// Idempotently ensure Test Course contains a configured Group Quiz activity.

define('CLI_SCRIPT', true);
require('/var/www/html/config.php');
require_once($CFG->libdir . '/clilib.php');
require_once($CFG->dirroot . '/course/modlib.php');
require_once($CFG->dirroot . '/group/lib.php');
require_once($CFG->dirroot . '/mod/groupquiz/lib.php');

list($options, $unrecognized) = cli_get_params(
    [
        'help' => false,
        'course' => 'Test Course',
        'name' => 'Group Quiz (Test)',
        'grouping' => 'Group Quiz Test Grouping',
        'group' => 'Group Quiz Test Group',
    ],
    ['h' => 'help']
);

if ($options['help']) {
    echo "Ensure a configured Group Quiz activity exists in a course.\n";
    echo "  --course=<fullname>  Target course full name (default: 'Test Course')\n";
    echo "  --name=<name>        Group Quiz activity name\n";
    echo "  --grouping=<name>    Grouping assigned to the activity\n";
    echo "  --group=<name>       Seed group assigned to the grouping\n";
    exit(0);
}

$course = $DB->get_record('course', ['fullname' => $options['course']]);
if (!$course) {
    cli_error("Course '{$options['course']}' not found. (create_course should run first.)");
}

$module = $DB->get_record('modules', ['name' => 'groupquiz']);
if (!$module) {
    cli_error('mod_groupquiz is not installed.');
}

$grouping = $DB->get_record('groupings', [
    'courseid' => $course->id,
    'name' => $options['grouping'],
]);
if (!$grouping) {
    $groupingdata = (object) [
        'courseid' => $course->id,
        'name' => $options['grouping'],
        'description' => 'Development grouping for the seeded Group Quiz activity.',
        'descriptionformat' => FORMAT_PLAIN,
    ];
    $groupingdata->id = groups_create_grouping($groupingdata);
    $grouping = $groupingdata;
    cli_writeln("Created grouping '{$grouping->name}' (ID {$grouping->id}).");
}

$group = $DB->get_record('groups', [
    'courseid' => $course->id,
    'name' => $options['group'],
]);
if (!$group) {
    $groupdata = (object) [
        'courseid' => $course->id,
        'name' => $options['group'],
        'description' => 'Development group for the seeded Group Quiz activity.',
        'descriptionformat' => FORMAT_PLAIN,
    ];
    $groupdata->id = groups_create_group($groupdata);
    $group = $groupdata;
    cli_writeln("Created group '{$group->name}' (ID {$group->id}).");
}

if (!$DB->record_exists('groupings_groups', [
    'groupingid' => $grouping->id,
    'groupid' => $group->id,
])) {
    groups_assign_grouping($group->id, $grouping->id);
    cli_writeln("Assigned group '{$group->name}' to grouping '{$grouping->name}'.");
}

$existing = $DB->get_record('groupquiz', [
    'course' => $course->id,
    'name' => $options['name'],
]);
if ($existing) {
    $updated = false;
    if ((int) $existing->grouping !== (int) $grouping->id) {
        $existing->grouping = $grouping->id;
        $existing->timemodified = time();
        $DB->update_record('groupquiz', $existing);
        $updated = true;
    }

    $cm = get_coursemodule_from_instance('groupquiz', $existing->id, $course->id, false, MUST_EXIST);
    if ((int) $cm->groupingid !== (int) $grouping->id) {
        $cm->groupingid = $grouping->id;
        $DB->update_record('course_modules', $cm);
        $updated = true;
    }

    if ($updated) {
        rebuild_course_cache($course->id, true);
        cli_writeln("Updated Group Quiz '{$existing->name}' to use grouping '{$grouping->name}'.");
    } else {
        cli_writeln("Group Quiz '{$existing->name}' already exists with the seeded grouping. Nothing to do.");
    }
    exit(0);
}

\core\session\manager::set_user(get_admin());

$moduleinfo = new stdClass();
$moduleinfo->modulename = 'groupquiz';
$moduleinfo->module = $module->id;
$moduleinfo->course = $course->id;
$moduleinfo->section = 0;
$moduleinfo->visible = 1;
$moduleinfo->visibleoncoursepage = 1;
$moduleinfo->groupingid = $grouping->id;
$moduleinfo->name = $options['name'];
$moduleinfo->intro = 'Seeded development activity for validating Group Quiz behavior and styling.';
$moduleinfo->introformat = FORMAT_PLAIN;
$moduleinfo->timeopen = 0;
$moduleinfo->timeclose = 0;
$moduleinfo->timelimit = 3600;
$moduleinfo->grade = 100;
$moduleinfo->grademethod = 1;
$moduleinfo->grouping = $grouping->id;
$moduleinfo->shuffleanswers = 0;
$moduleinfo->showuserpicture = 1;
$moduleinfo->requireallmemberssubmit = 0;
$moduleinfo->attemptopen = 1;
$moduleinfo->attemptclosed = 1;
$moduleinfo->correctnessopen = 1;
$moduleinfo->correctnessclosed = 1;
$moduleinfo->marksopen = 1;
$moduleinfo->marksclosed = 1;
$moduleinfo->specificfeedbackopen = 1;
$moduleinfo->specificfeedbackclosed = 1;
$moduleinfo->generalfeedbackopen = 1;
$moduleinfo->generalfeedbackclosed = 1;
$moduleinfo->rightansweropen = 1;
$moduleinfo->rightanswerclosed = 1;
$moduleinfo->overallfeedbackclosed = 1;
$moduleinfo->manualcommentclosed = 1;

try {
    $created = add_moduleinfo($moduleinfo, $course);
    cli_writeln("Created Group Quiz '{$options['name']}' (cmid {$created->coursemodule}) in '{$course->fullname}'.");
} catch (Throwable $e) {
    cli_error("Failed to create Group Quiz activity: " . $e->getMessage());
}
