<?php
// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.
//
// Idempotently seed a course with one correctly configured activity per module
// type, so a fresh container has something to demonstrate and something for
// aiplacement_competency's Classify drawer to read.
//
// One activity per type, all to the same standard: a filled in description plus
// real content in whatever field that module keeps its content in. Deliberately
// incomplete activities are not seeded here - the plugin's phpunit suite already
// pins the button visibility gate from both directions, and a shared demo course
// is the wrong place to duplicate a unit test.
//
// Activities are matched by name, so editing the text below will not update an
// activity that already exists. Delete it in the course and re-run, or reset the
// "Demo Activities" line in /tmp/script_status.log.
//
// Both Moodle instances build from this same image, so this runs on 5.0 and on
// 5.2. Only /var/www/html/config.php is hardcoded, which is outside the 5.2
// public/ directory and so is in the same place on both; everything else goes
// through $CFG->dirroot, which 5.2 points at public/.

define('CLI_SCRIPT', true);
require('/var/www/html/config.php');
require_once($CFG->libdir . '/clilib.php');
require_once($CFG->libdir . '/questionlib.php');
require_once($CFG->dirroot . '/course/lib.php');
require_once($CFG->dirroot . '/mod/quiz/locallib.php');

list($options, $unrecognized) = cli_get_params(
    [
        'help' => false,
        'course' => 'Test Course',
    ],
    ['h' => 'help']
);

if ($options['help']) {
    echo "Ensure demo activities exist in a course.\n";
    echo "  --course=<fullname>  Target course full name (default: 'Test Course')\n";
    exit(0);
}

$course = $DB->get_record('course', ['fullname' => $options['course']]);
if (!$course) {
    cli_error("Course '{$options['course']}' not found. (create_course should run first.)");
}

// Questions record their author, and creating an activity fires events that
// expect a real user.
\core\session\manager::set_user(get_admin());

/**
 * Fills in the columns a table insists on that the caller did not supply.
 *
 * These activities are built by inserting the instance row directly rather than
 * through each module's add_instance(), which expects form data, draft file
 * areas and in some cases an mform. The trade-off is that no grade item or
 * calendar event is created, which does not matter for demonstrating the
 * settings form or for reading text back off it.
 *
 * @param string $table The module table being written.
 * @param array $record The fields the caller supplied.
 * @return array The record with every other mandatory column filled in.
 */
function demo_fill_required(string $table, array $record): array {
    global $DB;

    foreach ($DB->get_columns($table) as $name => $column) {
        if ($name === 'id' || array_key_exists($name, $record)) {
            continue;
        }
        if (!$column->not_null || $column->has_default) {
            continue;
        }
        $record[$name] = in_array($column->meta_type, ['C', 'X'], true) ? '' : 0;
    }

    return $record;
}

/**
 * Creates an activity and puts it in the course's first section.
 *
 * @param stdClass $course The course to add to.
 * @param string $modname The module name, e.g. 'book'.
 * @param string $name The activity name, which is also its identity here.
 * @param array $fields The instance fields, intro included.
 * @return array|null [int $instanceid, int $cmid, bool $created], or null when the module is missing.
 */
function demo_create_activity(stdClass $course, string $modname, string $name, array $fields): ?array {
    global $DB;

    $moduleid = $DB->get_field('modules', 'id', ['name' => $modname]);
    if (!$moduleid) {
        cli_writeln("  mod_{$modname} is not installed - skipping '{$name}'.");
        return null;
    }

    $existing = $DB->get_record($modname, ['course' => $course->id, 'name' => $name], 'id');
    if ($existing) {
        cli_writeln("  '{$name}' already exists.");
        $cm = get_coursemodule_from_instance($modname, $existing->id, $course->id, false, MUST_EXIST);

        return [(int)$existing->id, (int)$cm->id, false];
    }

    $record = demo_fill_required($modname, $fields + [
        'course' => $course->id,
        'name' => $name,
        'introformat' => FORMAT_HTML,
        'timecreated' => time(),
        'timemodified' => time(),
    ]);

    $instanceid = $DB->insert_record($modname, (object)$record);

    $cmid = add_course_module((object)[
        'course' => $course->id,
        'module' => $moduleid,
        'instance' => $instanceid,
        'section' => 0,
        'visible' => 1,
        'visibleoncoursepage' => 1,
    ]);
    course_add_cm_to_section($course->id, $cmid, 0);

    cli_writeln("  Created '{$name}' (cmid {$cmid}).");

    return [(int)$instanceid, (int)$cmid, true];
}

/**
 * Adds a chapter to a book.
 *
 * @param int $bookid The book to add to.
 * @param int $pagenum The chapter's position.
 * @param string $title The chapter title.
 * @param string $content The chapter content, as HTML.
 * @param int $subchapter 1 when this is a subchapter of the one before it.
 */
function demo_add_chapter(int $bookid, int $pagenum, string $title, string $content,
        int $subchapter = 0): void {
    global $DB;

    $DB->insert_record('book_chapters', (object)[
        'bookid' => $bookid,
        'pagenum' => $pagenum,
        'subchapter' => $subchapter,
        'title' => $title,
        'content' => $content,
        'contentformat' => FORMAT_HTML,
        'hidden' => 0,
        'importsrc' => '',
        'timecreated' => time(),
        'timemodified' => time(),
    ]);
}

/**
 * Adds content pages to a lesson, chained in the order given.
 *
 * Lesson pages are a linked list rather than an ordered column, so the chain is
 * wired up explicitly here. That is also what a reader walks, so a lesson with a
 * broken chain would not demonstrate anything.
 *
 * @param int $lessonid The lesson to add to.
 * @param array $pages List of [title, contents] pairs, in presentation order.
 */
function demo_add_lesson_pages(int $lessonid, array $pages): void {
    global $DB;

    $ids = [];
    foreach ($pages as $page) {
        [$title, $contents] = $page;
        $ids[] = $DB->insert_record('lesson_pages', (object)[
            'lessonid' => $lessonid,
            'prevpageid' => 0,
            'nextpageid' => 0,
            // LESSON_PAGE_BRANCHTABLE, which is what a content page is.
            'qtype' => 20,
            'qoption' => 0,
            'layout' => 1,
            'display' => 1,
            'title' => $title,
            'contents' => $contents,
            'contentsformat' => FORMAT_HTML,
            'timecreated' => time(),
            'timemodified' => time(),
        ]);
    }

    foreach ($ids as $i => $id) {
        $DB->update_record('lesson_pages', (object)[
            'id' => $id,
            'prevpageid' => $ids[$i - 1] ?? 0,
            'nextpageid' => $ids[$i + 1] ?? 0,
        ]);
    }
}

/**
 * Returns the question category the demo questions live in.
 *
 * Moodle 5.0 moved question banks into mod_qbank activities and
 * question_get_default_category() now refuses anything but a module context, so
 * the demo questions get a bank of their own rather than writing into the system
 * shared bank.
 *
 * @param stdClass $course The course to hold the bank.
 * @param string $name The bank activity name.
 * @return stdClass|null The default category of the bank, or null if unavailable.
 */
function demo_question_category(stdClass $course, string $name): ?stdClass {
    global $DB;

    $cmid = $DB->get_field_sql(
        "SELECT cm.id
           FROM {course_modules} cm
           JOIN {modules} m ON m.id = cm.module
           JOIN {qbank} q ON q.id = cm.instance
          WHERE m.name = 'qbank' AND cm.course = ? AND q.name = ?",
        [$course->id, $name]
    );

    if (!$cmid) {
        $bank = demo_create_activity($course, 'qbank', $name, [
            'intro' => '<p>Questions used by the demo quiz.</p>',
            'type' => 'standard',
        ]);
        if (!$bank) {
            return null;
        }
        $cmid = $bank[1];
    }

    $category = question_get_default_category(\context_module::instance((int)$cmid)->id, true);

    return $category ?: null;
}

/**
 * Creates a true/false question in the given category.
 *
 * @param stdClass $category The question category to save into.
 * @param string $name The question name.
 * @param string $questiontext The question text, as HTML.
 * @return stdClass The saved question.
 */
function demo_create_question(stdClass $category, string $name, string $questiontext): stdClass {
    $form = (object)[
        'category' => $category->id,
        'name' => $name,
        'questiontext' => ['text' => $questiontext, 'format' => FORMAT_HTML, 'itemid' => 0],
        'generalfeedback' => ['text' => '', 'format' => FORMAT_HTML, 'itemid' => 0],
        'defaultmark' => 1,
        'penalty' => 1,
        'correctanswer' => 1,
        'feedbacktrue' => ['text' => '', 'format' => FORMAT_HTML, 'itemid' => 0],
        'feedbackfalse' => ['text' => '', 'format' => FORMAT_HTML, 'itemid' => 0],
    ];

    return \question_bank::get_qtype('truefalse')->save_question((object)['qtype' => 'truefalse'], $form);
}

cli_writeln("Seeding demo activities in '{$course->fullname}'");

// A book, whose content lives in its chapters rather than on the settings form.
$book = demo_create_activity($course, 'book', 'Demo Book', [
    'intro' => '<p>This book covers network traffic analysis for intrusion detection.</p>',
    'numbering' => 1,
    'navstyle' => 1,
    'customtitles' => 0,
]);
if ($book && $book[2]) {
    demo_add_chapter($book[0], 1, 'Collecting network telemetry',
        '<p>Capture and retain flow records and packet metadata from perimeter and internal sensors, and '
        . 'verify coverage against the network diagram.</p>');
    demo_add_chapter($book[0], 2, 'Correlating indicators',
        '<p>Correlate authentication logs with outbound connection records to identify anomalous sessions, '
        . 'and document indicators of compromise for escalation.</p>');
    demo_add_chapter($book[0], 3, 'Worked example',
        '<p>Trace a beaconing host from its first DNS request through to containment.</p>', 1);
}

// A lesson, whose pages are chained rather than ordered by a column.
$lesson = demo_create_activity($course, 'lesson', 'Demo Lesson', [
    'intro' => '<p>A walkthrough of triaging a suspected phishing report.</p>',
    'grade' => 100,
    'available' => 0,
    'deadline' => 0,
]);
if ($lesson && $lesson[2]) {
    demo_add_lesson_pages($lesson[0], [
        ['Receiving the report', '<p>Preserve the original message with headers intact and open a case '
            . 'record before touching anything else.</p>'],
        ['Assessing the message', '<p>Examine sender authentication results, embedded URLs and attachments '
            . 'in an isolated environment.</p>'],
        ['Deciding on containment', '<p>Recommend blocking, recall or user notification, and state what '
            . 'evidence supports the choice.</p>'],
    ]);
}

// A page, whose content is a field on its own instance row.
demo_create_activity($course, 'page', 'Demo Page', [
    'intro' => '<p>Reference material on evidence handling.</p>',
    'content' => '<p>Record who collected each artefact, when, and how it was hashed, so that the chain of '
        . 'custody holds up under review.</p>',
    'contentformat' => FORMAT_HTML,
    'display' => 5,
    'displayoptions' => serialize(['printintro' => 1, 'printlastmodified' => 1]),
    'legacyfiles' => 0,
]);

// An assignment, whose instructions live in a field separate from the description.
demo_create_activity($course, 'assign', 'Demo Assignment', [
    'intro' => '<p>Submit a written incident report.</p>',
    'activity' => '<p>Reconstruct the timeline of the provided incident, name the techniques observed, and '
        . 'recommend remediation in priority order.</p>',
    'activityformat' => FORMAT_HTML,
    'grade' => 100,
]);

// A workshop, whose two instruction fields are on tabs of their own.
demo_create_activity($course, 'workshop', 'Demo Workshop', [
    'intro' => '<p>Peer review of hardening plans.</p>',
    'instructauthors' => '<p>Produce a hardening plan for the supplied server build, citing the control that '
        . 'justifies each change.</p>',
    'instructauthorsformat' => FORMAT_HTML,
    'instructreviewers' => '<p>Judge whether each proposed change is traceable to a control and whether the '
        . 'plan would survive a rebuild.</p>',
    'instructreviewersformat' => FORMAT_HTML,
    // PHASE_SETUP, so the activity opens in a sane state if anyone visits it.
    'phase' => 10,
    'strategy' => 'accumulative',
    'evaluation' => 'best',
    'grade' => 80,
    'gradinggrade' => 20,
    'grademapping' => '',
]);

// A quiz with real questions, which is the only activity here that needs a
// question bank. Its questions are its content; the description alone would not
// say much about it.
//
// Its questions are split across the two places a quiz can keep them, because
// both still work in 5.0 and 5.2 and each has its own page in the UI:
//
//   Demo Question Bank (a mod_qbank activity)  any quiz can reuse these
//   the quiz's own module context               private to this quiz
//
// Without one of each, whichever page you happen to open looks broken.
$quiz = demo_create_activity($course, 'quiz', 'Demo Quiz', [
    'intro' => '<p>Check your understanding of log analysis.</p>',
    'questionsperpage' => 0,
    'grade' => 100,
    'sumgrades' => 0,
]);
// quiz_add_instance() creates the quiz's first section, and mod_quiz cannot lay
// out its structure without one: the questions exist and are graded, but the
// edit page draws an empty quiz. Inserting the instance row directly skips that,
// so the section is added here.
if ($quiz && !$DB->record_exists('quiz_sections', ['quizid' => $quiz[0]])) {
    $DB->insert_record('quiz_sections', (object)[
        'quizid' => $quiz[0],
        'firstslot' => 1,
        'heading' => '',
        'shufflequestions' => 0,
    ]);
}

// Checked against the slots rather than against whether the quiz was just
// created, so a quiz left question-less by an earlier failed run is repaired.
if ($quiz && !$DB->record_exists('quiz_slots', ['quizid' => $quiz[0]])) {
    try {
        $category = demo_question_category($course, 'Demo Question Bank');
        if (!$category) {
            throw new moodle_exception('No question bank available for the demo questions.');
        }

        $quizrecord = $DB->get_record('quiz', ['id' => $quiz[0]], '*', MUST_EXIST);
        $quizrecord->cmid = $quiz[1];

        // The quiz's own context. question_get_default_category() creates the
        // category on first use, which is also what visiting the quiz's Question
        // bank page does.
        $ownbank = question_get_default_category(\context_module::instance((int)$quiz[1])->id, true);
        if (!$ownbank) {
            throw new moodle_exception('No question category available in the quiz context.');
        }

        foreach ([
            [$category, 'Failed authentication spikes are always benign',
                '<p>A sudden spike in failed authentication attempts from a single source can be ignored if '
                . 'no account was locked out.</p>'],
            [$category, 'Log retention is an availability control only',
                '<p>Retaining logs long enough to investigate an incident is purely a question of storage '
                . 'capacity, not of investigative capability.</p>'],
            [$ownbank, 'Clock skew does not affect log correlation',
                '<p>Timestamps from different hosts can be compared directly without reconciling their '
                . 'clocks, so long as each host is internally consistent.</p>'],
        ] as [$bank, $qname, $qtext]) {
            $question = demo_create_question($bank, $qname, $qtext);
            quiz_add_quiz_question($question->id, $quizrecord);
            $where = $bank->id === $category->id ? 'bank' : 'quiz context';
            cli_writeln("  Added quiz question ({$where}) '{$qname}'.");
        }

        // 5.2 dropped quiz_update_sumgrades(). The grade calculator behind it is
        // present on both branches, so go straight to that.
        \mod_quiz\quiz_settings::create((int)$quiz[0])->get_grade_calculator()->recompute_quiz_sumgrades();
    } catch (Throwable $e) {
        // The quiz still exists with its description, so the rest of the
        // activities remain usable. Worth a loud line rather than a failed
        // section. save_question() opens a transaction, so it has to be unwound
        // here or Moodle complains at shutdown and leaves the connection dirty.
        if ($DB->is_transaction_started()) {
            $DB->force_transaction_rollback();
        }
        cli_writeln('  Could not add quiz questions: ' . $e->getMessage());
    }
}

// A label, which has nowhere to put content but its description.
demo_create_activity($course, 'label', 'Demo Label', [
    'intro' => '<p>Reminder: bring the incident report template to the next session.</p>',
]);

rebuild_course_cache($course->id, true);
cli_writeln('Demo activities ready.');
