<?php
// Copyright 2025 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

// setup_environment.php — multi-function CLI, retains category creation as-is
define('CLI_SCRIPT', true);
require('/var/www/html/config.php');

require_once($CFG->libdir . '/clilib.php');
require_once($CFG->dirroot . '/course/lib.php');

// Parse CLI options
list($options, $unrecognized) = cli_get_params([
    'step' => null,

    // OAuth2 options
    'id' => '',
    'baseurl' => '',
    'clientid' => '',
    'clientsecret' => '',
    'loginscopes' => '',
    'loginscopesoffline' => '',
    'loginparams' => '',
    'loginparamsoffline' => '',
    'name' => '',
    'showonloginpage' => true,
    'image' => '',
    'list' => false,
    'delete' => false,
    'delete-all' => false,
    'create-user-field' => false,
    'json' => false,
    'requireconfirmation' => false,
    'tokenendpoint' => '',
    'userinfoendpoint' => '',
    'accesskeyid'     => '',
    'secretaccesskey' => '',
    'sessiontoken' => '',
    'region'          => '',
    'modelid'         => '',
]);

// Step dispatcher
switch ($options['step']) {
    case 'manage_oauth':
        manage_oauth($options);
        break;

    case 'enable_auth_oauth2':
        enable_auth_oauth2();
        break;
    case 'configure_ai_bedrock':
        if (empty($options['accesskeyid']) || empty($options['secretaccesskey']) || empty($options['sessiontoken'] ||
            empty($options['region']) || empty($options['modelid']))) {
            cli_error("Missing required parameters. Current values:\n" .
                      "  --accesskeyid={$options['accesskeyid']}\n" .
                      "  --secretaccesskey={$options['secretaccesskey']}\n" .
                      "  --sessiontoken={$options['sessiontoken']}\n" .
                      "  --region={$options['region']}\n" .
                      "  --modelid={$options['modelid']}");
        }
        configure_ai_bedrock($options);
        break;

    default:
        cli_error("Unknown step: {$options['step']}");
}

function manage_oauth($options) {
    global $CFG;
    require_once("$CFG->libdir/clilib.php");
    require_once("$CFG->libdir/adminlib.php");
    require_once($CFG->dirroot . '/user/lib.php');
    \core\session\manager::set_user(get_admin());

    $api = new \core\oauth2\api();
    $issuer_settings = [
        'id', 'baseurl', 'clientid', 'clientsecret', 'loginscopes',
        'loginscopesoffline', 'name', 'image', 'showonloginpage',
        'requireconfirmation', 'loginparams', 'loginparamsoffline', 'alloweddomains',
    ];

    $results = ['success' => true, 'data' => []];

    if ($options['create-user-field'] && $options['id'] && $options['json']) {
        $mapping_data = json_decode($options['json']);
        if (!$mapping_data || !isset($mapping_data->externalfieldname) || !isset($mapping_data->internalfieldname)) {
            cli_error("Invalid or missing JSON data for user field mapping.");
        }

        $data = new stdClass();
        $data->issuerid = $options['id'];
        $data->externalfield = $mapping_data->externalfieldname;
        $data->internalfield = $mapping_data->internalfieldname;

        try {
            \core\oauth2\api::create_user_field_mapping($data);
            cli_writeln("User field mapping created for provider ID {$options['id']}.");
        } catch (Exception $e) {
            cli_error("Error creating user field mapping: " . $e->getMessage());
        }
        return;
    }

    if ($options['list']) {
        if ($options['id']) {
            $issuer = $api->get_issuer($options['id']);
            if (!$issuer) {
                $results['success'] = false;
                $results['data'] = 'Provider not found.';
            } else {
                foreach ($issuer_settings as $key) {
                    $results['data'][$key] = $issuer->get($key);
                }
            }
        } else {
            foreach ($api->get_all_issuers() as $issuer) {
                $item = [];
                foreach ($issuer_settings as $key) {
                    $item[$key] = $issuer->get($key);
                }
                $results['data'][] = $item;
            }
        }
        output_results($options, $results);
        return;
    }

    if ($options['delete'] && $options['id']) {
        $issuer = $api->get_issuer($options['id']);
        if (!$issuer) {
            cli_error("Provider with ID {$options['id']} not found.");
        }
        $api->delete_issuer($options['id']);
        cli_writeln("Deleted provider with ID {$options['id']}");
        return;
    }

    if ($options['delete-all']) {
        foreach ($api->get_all_issuers() as $issuer) {
            $id = $issuer->get('id');
            if ($id) {
                $api->delete_issuer($id);
                cli_writeln("Deleted provider with ID {$id}");
            }
        }
        cli_writeln("Deleted all OAuth providers.");
        return;
    }

    $data = (object)[];
    foreach (['id', 'baseurl', 'clientid', 'clientsecret', 'loginscopes', 'loginscopesoffline', 'name', 'image', 'showonloginpage', 'requireconfirmation'] as $key) {
        if (isset($options[$key]) && $options[$key] !== '') {
            $data->$key = $options[$key];
        }
    }

    if (empty($data->baseurl) || empty($data->clientid) || empty($data->clientsecret) || empty($data->name)) {
        cli_error("Missing required fields: baseurl, clientid, clientsecret, name.");
    }

    if (empty($data->id)) {
        $issuer = $api->create_issuer($data);
        $issuerid = $issuer->get('id');
        if ($issuerid) {
            cli_writeln("Created provider with ID {$issuerid}");
        } else {
            cli_error("Failed to retrieve ID of new provider.");
        }
    } else {
        $api->update_issuer($data);
        cli_writeln("Updated provider with ID {$data->id}");
    }

    // Update endpoint
    $tokenurl    = $options['tokenendpoint'] ?? '';
    $userinfourl = $options['userinfoendpoint'] ?? '';

    if ($tokenurl !== '' || $userinfourl !== '') {
        // Get existing endpoints
        $existing = [];
        foreach (\core\oauth2\api::get_endpoints($issuer) as $endpoint) {
            $existing[$endpoint->get('name')] = $endpoint;
        }

        // Token endpoint.
        if ($tokenurl !== '') {
            $edata = new stdClass();
            $edata->issuerid = $issuerid;
            $edata->name     = 'token_endpoint';
            $edata->url      = $tokenurl;

            if (isset($existing['token_endpoint'])) {
                $edata->id = $existing['token_endpoint']->get('id');
                \core\oauth2\api::update_endpoint($edata);
                cli_writeln("Updated token_endpoint for issuer ID {$issuerid} to {$tokenurl}");
            } else {
                \core\oauth2\api::create_endpoint($edata);
                cli_writeln("Created token_endpoint for issuer ID {$issuerid} with URL {$tokenurl}");
            }
        }

        // Userinfo endpoint.
        if ($userinfourl !== '') {
            $edata = new stdClass();
            $edata->issuerid = $issuerid;
            $edata->name     = 'userinfo_endpoint';
            $edata->url      = $userinfourl;

            if (isset($existing['userinfo_endpoint'])) {
                $edata->id = $existing['userinfo_endpoint']->get('id');
                \core\oauth2\api::update_endpoint($edata);
                cli_writeln("Updated userinfo_endpoint for issuer ID {$issuerid} to {$userinfourl}");
            } else {
                \core\oauth2\api::create_endpoint($edata);
                cli_writeln("Created userinfo_endpoint for issuer ID {$issuerid} with URL {$userinfourl}");
            }
        }
    }
}

function enable_auth_oauth2() {
    // Ensure the class is available
    if (!class_exists('\auth_oauth2\api')) {
        throw new \moodle_exception('auth_oauth2 API class not found');
    }

    if (!\auth_oauth2\api::is_enabled()) {
        if (method_exists('\auth_oauth2\api', 'set_enabled')) {
            \auth_oauth2\api::set_enabled(true);
        } else {
            // Fallback for older versions where only config string is used
            $enabled = get_enabled_auth_plugins(true);
            $enabled[] = 'oauth2';
            set_config('auth', implode(',', array_unique($enabled)));
        }
    }
}

function output_results($options, $results) {
    if ($options['json']) {
        echo json_encode($results, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n";
    } else {
        print_r($results);
    }
}

function configure_ai_bedrock(array $options): void {
    global $CFG, $DB;

    require_once($CFG->libdir . '/adminlib.php');
    require_once($CFG->dirroot . '/user/lib.php');

    \core\session\manager::set_user(get_admin());

    // Get credentials from CLI arguments
    $accessKeyId = $options['accesskeyid'];
    $secretAccessKey = $options['secretaccesskey'];
    $sessionToken = $options['sessiontoken'];
    $region = $options['region'];
    $modelId = $options['modelid'];
    $providerName = 'IMCITE Bedrock';

    cli_writeln("Configuring AWS Bedrock AI provider: {$providerName}");

    // Check if provider already exists
    $existingProvider = $DB->get_record('ai_providers', [
        'provider' => 'aiprovider_bedrock\\provider',
        'name' => $providerName
    ]);

    // Build config JSON
    $config = [
        'aiprovider' => 'aiprovider_bedrock',
        'name' => $providerName,
        'accesskeyid' => $accessKeyId,
        'secretaccesskey' => $secretAccessKey,
        'sessiontoken' => $sessionToken,
        'region' => $region,
    ];

    // Build actionconfig JSON with all AI actions
    // Only set model - Moodle will use default system instructions
    $actionconfig = [
        'core_ai\\aiactions\\generate_text' => [
            'enabled' => true,
            'settings' => [
                'model' => $modelId
            ]
        ],
        'core_ai\\aiactions\\summarise_text' => [
            'enabled' => true,
            'settings' => [
                'model' => $modelId
            ]
        ],
        'core_ai\\aiactions\\explain_text' => [
            'enabled' => true,
            'settings' => [
                'model' => $modelId
            ]
        ],
        'core_ai\\aiactions\\generate_image' => [
            'enabled' => true,
            'settings' => []
        ]
    ];

    if ($existingProvider) {
        // Update existing provider
        $config['updateandreturn'] = 'Update instance';
        $config['returnurl'] = 'https://' . $_SERVER['HTTP_HOST'] . '/admin/settings.php?section=aiprovider';
        $config['id'] = $existingProvider->id;

        // Add providerid to actionconfig settings
        foreach ($actionconfig as $action => &$actiondata) {
            if (isset($actiondata['settings'])) {
                $actiondata['settings']['providerid'] = $existingProvider->id;
            }
        }

        $existingProvider->config = json_encode($config);
        $existingProvider->actionconfig = json_encode($actionconfig);
        $existingProvider->enabled = 1;

        $DB->update_record('ai_providers', $existingProvider);
        cli_writeln("Updated existing AI provider (ID: {$existingProvider->id})");
    } else {
        // Create new provider
        $config['createandreturn'] = 'Create instance';
        $config['returnurl'] = 'https://' . $_SERVER['HTTP_HOST'] . '/admin/settings.php?section=aiprovider';

        $record = new stdClass();
        $record->name = $providerName;
        $record->provider = 'aiprovider_bedrock\\provider';
        $record->enabled = 1;
        $record->config = json_encode($config);
        $record->actionconfig = json_encode($actionconfig);

        $newid = $DB->insert_record('ai_providers', $record);

        // Update actionconfig with providerid
        foreach ($actionconfig as $action => &$actiondata) {
            if (isset($actiondata['settings'])) {
                $actiondata['settings']['providerid'] = $newid;
            }
        }
        $record->id = $newid;
        $record->actionconfig = json_encode($actionconfig);
        $DB->update_record('ai_providers', $record);

        cli_writeln("Created new AI provider (ID: {$newid})");
    }

    cli_writeln("AWS Bedrock AI provider configured successfully:");
    cli_writeln("  - Provider Name: {$providerName}");
    cli_writeln("  - Region: {$region}");
    cli_writeln("  - Model: {$modelId}");
    cli_writeln("  - Access Key ID: " . substr($accessKeyId, 0, 8) . "...");
    cli_writeln("  - Actions configured: generate_text, summarise_text, explain_text, generate_image");

    // Purge caches
    if (class_exists('\\cache_helper')) {
        \cache_helper::purge_all();
        cli_writeln("Purged caches.");
    }
}

?>
