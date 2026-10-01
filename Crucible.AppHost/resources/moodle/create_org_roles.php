<?php
// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.
//
// Idempotently create the top level course categories and the category scoped
// roles that block_crucible's org role sync needs before it will do anything.
//
// The sync assigns a Moodle role in an organization's category context based on
// the user's Keycloak group membership. It will not create either side itself:
// sync_org_roles skips an org with no matching category (deliberately, so a typo
// in a Keycloak attribute cannot conjure a category) and warns and skips when the
// role shortname does not exist. So both have to be seeded here, matching the
// organization attributes in crucible-realm.json and the shortnames in
// block_crucible's GROUP_ROLE_MAP.
//
// A category is matched by its exact name, or by idnumber org-<slug>, so both are
// set. The capability sets are archetype defaults, not the definitions the real
// deployments use - those live in a moodle-install.sh that is not in this repo.
// They are here so the sync has something real to assign and so a category role
// assignment is visible in the UI; do not treat them as the authoritative
// permissions for these roles.
//
// Both Moodle instances build from this same image, so this runs on 5.0 and 5.2.

define('CLI_SCRIPT', true);
require('/var/www/html/config.php');
require_once($CFG->libdir . '/clilib.php');
require_once($CFG->libdir . '/accesslib.php');

// Must line up with the organization attribute values in crucible-realm.json.
// "Demo Org Reserve" exists to catch substring matching: a sync that matches the
// organization as a substring puts Reserve users into "Demo Org" as well.
$categories = [
    'Demo Org',
    'Demo Org Reserve',
    'Second Org',
];

// Shortnames must match block_crucible's GROUP_ROLE_MAP values exactly.
$roles = [
    'cyber-manager' => [
        'name' => 'Cyber Manager',
        'description' => 'Manages an organization\'s courses and users. Assigned by block_crucible from the Keycloak cyber-managers group.',
        'archetype' => 'manager',
    ],
    'lab-builder' => [
        'name' => 'Lab Builder',
        'description' => 'Builds lab activities in an organization\'s courses. Assigned by block_crucible from the Keycloak lab-builders group.',
        'archetype' => 'editingteacher',
    ],
    'curriculum-developer' => [
        'name' => 'Curriculum Developer',
        'description' => 'Creates and authors an organization\'s courses. Assigned by block_crucible from the Keycloak curriculum-developers group.',
        'archetype' => 'coursecreator',
    ],
];

$slugify = static function (string $value): string {
    return strtolower(preg_replace('/[^a-zA-Z0-9]+/', '-', trim($value)));
};

foreach ($categories as $name) {
    $idnumber = 'org-' . $slugify($name);

    if ($DB->record_exists('course_categories', ['name' => $name, 'parent' => 0])) {
        cli_writeln("Category '{$name}' already exists - skipping.");
        continue;
    }
    if ($DB->record_exists('course_categories', ['idnumber' => $idnumber, 'parent' => 0])) {
        cli_writeln("Category with idnumber '{$idnumber}' already exists - skipping.");
        continue;
    }

    $category = \core_course_category::create([
        'name' => $name,
        'idnumber' => $idnumber,
        'parent' => 0,
        'description' => 'Organization category. block_crucible assigns org roles in this context.',
        'descriptionformat' => FORMAT_HTML,
    ]);
    cli_writeln("Created category '{$name}' (id {$category->id}, idnumber {$idnumber}).");
}

foreach ($roles as $shortname => $role) {
    if ($DB->record_exists('role', ['shortname' => $shortname])) {
        cli_writeln("Role '{$shortname}' already exists - skipping.");
        continue;
    }

    $roleid = create_role($role['name'], $shortname, $role['description'], $role['archetype']);

    // Assignable in a category context only: these roles exist to scope a user to
    // one organization, and leaving the site level on would let an admin hand out
    // manager rights over the whole site by picking the wrong context.
    set_role_contextlevels($roleid, [CONTEXT_COURSECAT]);

    // create_role() copies the archetype's name and description but not its
    // capabilities; this fills them in from the archetype defaults.
    reset_role_capabilities($roleid);

    cli_writeln("Created role '{$shortname}' (id {$roleid}) from archetype '{$role['archetype']}'.");
}

cli_writeln('Org categories and roles are in place.');
