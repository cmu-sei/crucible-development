<?php
// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.
//
// Shared helpers for the two lab activity seeders, create_topomojo_activity.php
// and create_crucible_activity.php.
//
// Those are separate scripts rather than one because mod_topomojo and
// mod_crucible both declare a global setup() in their locallib.php, and each
// plugin's add_instance() require_once's its own locallib. Seeding both in one
// process therefore fatals on "Cannot redeclare setup()" as soon as the second
// activity is created, which is silent under CLI - the process just stops with
// an open transaction. Keep them in separate processes.

defined('MOODLE_INTERNAL') || die();

/**
 * Picks the service-side item to point a demo activity at.
 *
 * Prefers the caller's named item so a seeded activity can be pinned to known
 * content, and otherwise takes the alphabetically first one so that two runs
 * against the same service agree on the answer.
 *
 * @param array $items Decoded API objects, each with an id and a name.
 * @param string $preferred The name to look for first, or '' for no preference.
 * @return stdClass|null The chosen item, or null when there is nothing to choose.
 */
function lab_pick_item(array $items, string $preferred): ?stdClass {
    if (!$items) {
        return null;
    }

    if ($preferred !== '') {
        foreach ($items as $item) {
            if (isset($item->name) && $item->name === $preferred) {
                return $item;
            }
        }
    }

    usort($items, fn($a, $b) => strcasecmp($a->name ?? '', $b->name ?? ''));

    return $items[0];
}

/**
 * Creates an activity in the course's first section, or reports the existing one.
 *
 * Goes through add_moduleinfo() rather than inserting the instance row, so the
 * plugin's own add_instance() runs and the activity gets its grade item.
 *
 * @param stdClass $course The course to add to.
 * @param string $modname The module name, 'topomojo' or 'crucible'.
 * @param string $name The activity name to create it under.
 * @param array $fields The module specific instance fields, intro included.
 * @param array $match Instance fields identifying an activity this seeder already
 *      created, when the name is not one. Defaults to the name.
 */
function lab_create_activity(
    stdClass $course,
    string $modname,
    string $name,
    array $fields,
    array $match = []
): void {
    global $DB;

    $module = $DB->get_record('modules', ['name' => $modname]);
    if (!$module) {
        cli_writeln("  mod_{$modname} is not installed - skipping '{$name}'.");
        return;
    }

    $existing = $DB->get_records($modname, ($match ?: ['name' => $name]) + ['course' => $course->id]);
    if ($existing) {
        $first = reset($existing);
        cli_writeln("  '{$first->name}' already exists.");
        return;
    }

    $moduleinfo = (object)($fields + [
        'modulename' => $modname,
        'module' => $module->id,
        'course' => $course->id,
        'section' => 0,
        'visible' => 1,
        'visibleoncoursepage' => 1,
        'name' => $name,
        'introformat' => FORMAT_HTML,
        'timeopen' => 0,
        'timeclose' => 0,
        // add_moduleinfo() reads this when it builds the grade item, and warns
        // when it is missing.
        'cmidnumber' => '',
    ]);

    try {
        $created = add_moduleinfo($moduleinfo, $course);
        cli_writeln("  Created '{$name}' (cmid {$created->coursemodule}).");
    } catch (Throwable $e) {
        cli_writeln("  Could not create '{$name}': " . $e->getMessage());
    }
}

/**
 * Fetches the API list a seeder needs, as the Moodle OAuth2 issuer's service account.
 *
 * mod_crucible reads Alloy through its setup_system(), which needs a connected
 * system account that this environment does not have, so go straight to the
 * issuer's client credentials instead. The token request body has to be form
 * encoded by hand: handing curl->post() an array makes it send
 * multipart/form-data, which Keycloak rejects with invalid_client.
 *
 * @param string $plugin The plugin whose issuerid setting names the issuer.
 * @return string|null The bearer token, or null when one cannot be obtained.
 */
function lab_service_token(string $plugin): ?string {
    global $DB;

    $issuerid = get_config($plugin, 'issuerid');
    if (!$issuerid) {
        cli_writeln("  {$plugin} has no issuerid set - cannot authenticate.");
        return null;
    }

    $issuer = $DB->get_record('oauth2_issuer', ['id' => $issuerid]);
    $tokenurl = $DB->get_field('oauth2_endpoint', 'url', [
        'issuerid' => $issuerid,
        'name' => 'token_endpoint',
    ]);
    if (!$issuer || !$tokenurl || empty($issuer->clientid) || empty($issuer->clientsecret)) {
        cli_writeln('  OAuth2 issuer is missing a token endpoint or client credentials.');
        return null;
    }

    $client = new curl();
    $client->setHeader(['Content-Type: application/x-www-form-urlencoded']);
    $response = $client->post($tokenurl, http_build_query([
        'grant_type' => 'client_credentials',
        'client_id' => $issuer->clientid,
        'client_secret' => $issuer->clientsecret,
    ], '', '&'));

    $token = json_decode((string)$response);
    if (empty($token->access_token)) {
        $code = $client->info['http_code'] ?? 0;
        cli_writeln("  Client credentials grant failed (HTTP {$code}).");
        return null;
    }

    return $token->access_token;
}

/**
 * GETs a JSON list from a Crucible API with a bearer token.
 *
 * @param string $url The endpoint to read.
 * @param string $token The bearer token.
 * @return array|null The decoded list, or null on any failure.
 */
function lab_get_list(string $url, string $token): ?array {
    $client = new curl();
    $client->setHeader(['Authorization: Bearer ' . $token]);
    $response = $client->get($url);

    $code = $client->info['http_code'] ?? 0;
    if ($code !== 200) {
        cli_writeln("  GET {$url} returned HTTP {$code}.");
        return null;
    }

    $list = json_decode((string)$response);

    return is_array($list) ? $list : null;
}
