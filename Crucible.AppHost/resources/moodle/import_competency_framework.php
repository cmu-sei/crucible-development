<?php
// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.
//
// Idempotently import a competency framework from a tool_lpimportcsv CSV file.
//
// aiplacement_competency, tool_lptmanager and the competency reports all need at
// least one framework to have anything to show, and a fresh container has none.
// Core ships the importer but only wires it to a web form, so this drives
// tool_lpimportcsv\framework_importer directly.
//
// The framework is matched by the idnumber of the CSV's framework row, so this
// no-ops once it has run. Editing the CSV will not update an already imported
// framework: delete it under Site administration > Competencies > Competency
// frameworks and re-run, or reset the matching line in /tmp/script_status.log.
//
// Both Moodle instances build from this same image, so this runs on 5.0 and on
// 5.2. Only /var/www/html/config.php is hardcoded, which is outside the 5.2
// public/ directory and so is in the same place on both.

define('CLI_SCRIPT', true);
require('/var/www/html/config.php');
require_once($CFG->libdir . '/clilib.php');

list($options, $unrecognized) = cli_get_params(
    [
        'help' => false,
        'file' => '',
    ],
    ['h' => 'help']
);

if ($options['help'] || empty($options['file'])) {
    cli_writeln(<<<EOT
Import a competency framework from a tool_lpimportcsv CSV file.

Options:
  --file=PATH   CSV file to import, in tool_lpimportcsv's 14 column format.
  -h, --help    Print this help.

Example:
  php import_competency_framework.php --file=/usr/local/share/competency/nice-framework-v2.0.0.csv
EOT);
    exit($options['help'] ? 0 : 1);
}

$file = $options['file'];
if (!is_readable($file)) {
    cli_error("Cannot read competency framework CSV: {$file}");
}

$content = file_get_contents($file);
if ($content === false || trim($content) === '') {
    cli_error("Competency framework CSV is empty: {$file}");
}

// The framework's own row is the one flagged as a framework, and its idnumber is
// what makes this idempotent. Read it here rather than taking it as an argument,
// so the CSV stays the single source of truth.
$idnumber = null;
$shortname = null;
if (($handle = fopen($file, 'r')) !== false) {
    // Skip the header row: its "Is framework" cell is a label, not a flag.
    fgetcsv($handle);
    while (($row = fgetcsv($handle)) !== false) {
        if (count($row) >= 13 && trim((string) $row[12]) !== '') {
            $idnumber = trim((string) $row[1]);
            $shortname = trim((string) $row[2]);
            break;
        }
    }
    fclose($handle);
}

if ($idnumber === null || $idnumber === '') {
    cli_error("No row in {$file} is flagged as the framework, so there is nothing to import.");
}

if ($DB->record_exists('competency_framework', ['idnumber' => $idnumber])) {
    cli_writeln("Competency framework '{$idnumber}' already exists - skipping import.");
    exit(0);
}

// api::create_framework() and api::create_competency() are capability checked, and
// the importer stamps the scale it creates with $USER->id.
\core\session\manager::set_user(get_admin());

// No mapping data and no progress bar: the columns are in the importer's default
// order, and a progress bar would emit HTML into the container log.
$importer = new \tool_lpimportcsv\framework_importer($content, 'UTF-8', ',', 0, null, false);

$error = $importer->get_error();
if ($error) {
    cli_error("Could not parse {$file}: {$error}");
}

cli_writeln("Importing competency framework '{$shortname}' ({$idnumber}) from {$file}");
$framework = $importer->import();

$count = $DB->count_records('competency', ['competencyframeworkid' => $framework->get('id')]);
cli_writeln("Imported framework id {$framework->get('id')} with {$count} competencies.");
