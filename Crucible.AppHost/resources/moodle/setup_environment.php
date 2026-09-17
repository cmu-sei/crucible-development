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
        // --sessiontoken is optional: aiprovider_bedrock passes one when it is set, and core's
        // aiprovider_awsbedrock has nowhere to put it at all.
        if (
            empty($options['accesskeyid']) || empty($options['secretaccesskey']) ||
            empty($options['region']) || empty($options['modelid'])
        ) {
            cli_error("Missing required parameters. Current values:\n" .
                "  --accesskeyid={$options['accesskeyid']}\n" .
                "  --secretaccesskey={$options['secretaccesskey']}\n" .
                "  --region={$options['region']}\n" .
                "  --modelid={$options['modelid']}");
        }
        configure_ai_bedrock($options);
        break;

    default:
        cli_error("Unknown step: {$options['step']}");
}

function manage_oauth($options)
{
    global $CFG;
    require_once("$CFG->libdir/clilib.php");
    require_once("$CFG->libdir/adminlib.php");
    require_once($CFG->dirroot . '/user/lib.php');
    \core\session\manager::set_user(get_admin());

    $api = new \core\oauth2\api();
    $issuer_settings = [
        'id',
        'baseurl',
        'clientid',
        'clientsecret',
        'loginscopes',
        'loginscopesoffline',
        'name',
        'image',
        'showonloginpage',
        'requireconfirmation',
        'loginparams',
        'loginparamsoffline',
        'alloweddomains',
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
        $issuer = \core\oauth2\api::get_issuer($data->id);
        $issuerid = $data->id;
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

function enable_auth_oauth2()
{
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

function output_results($options, $results)
{
    if ($options['json']) {
        echo json_encode($results, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n";
    } else {
        print_r($results);
    }
}

/**
 * Work out which AWS Bedrock provider plugin to configure.
 *
 * Moodle 5.2 ships aiprovider_awsbedrock in core, so that is what we configure there.
 * The 5.0 image has no core provider and instead carries the bundled aiprovider_bedrock
 * plugin in the ai/provider bind mount.
 *
 * @return string The plugin component name.
 */
function bedrock_provider_plugin(): string
{
    if (\core_component::get_plugin_directory('aiprovider', 'awsbedrock') !== null) {
        return 'aiprovider_awsbedrock';
    }

    return 'aiprovider_bedrock';
}

function configure_ai_bedrock(array $options): void
{
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
    $imageModelId = 'amazon.nova-canvas-v1:0';

    $plugin = bedrock_provider_plugin();
    $usecore = ($plugin === 'aiprovider_awsbedrock');

    // Both provider plugins merge an action's modelextraparams into the request body — core in
    // abstract_processor::get_model_settings(), ours in abstract_processor::merge_extra_params() —
    // and a current Claude model needs two things through it:
    //
    //   max_tokens: Anthropic's InvokeModel API requires it and core's
    //   process_generate_text::create_anthropic_request() never sets one. The model templates in
    //   the settings UI carry it, but a hand-set model has no template, so every request comes
    //   back 400 "max_tokens: Field required". (Our own plugin already sets 1024 itself.)
    //
    //   thinking disabled: Claude 5 models sometimes lead with a "thinking" content block, and
    //   both plugins read content[0]'s text unconditionally (core
    //   process_generate_text.php:290, ours process_generate_text.php:162 and
    //   process_summarise_text.php:184). When a thinking block turns up the action still reports
    //   success but the text is empty — an AI feature that looks broken on some prompts and not
    //   others.
    //
    // Image generation goes through a different request builder in both plugins and uses neither.
    $textextraparams = json_encode([
        'max_tokens' => 1024,
        'thinking' => ['type' => 'disabled'],
    ]);

    cli_writeln("Configuring AWS Bedrock AI provider: {$providerName} ({$plugin})");

    // Match on the name alone rather than name plus provider class. A row seeded by an
    // earlier run can name the other plugin, and on 5.2 that class does not exist, so
    // matching on it too would leave the broken row behind and add a duplicate.
    $existingProvider = null;
    $matches = $DB->get_records('ai_providers', ['name' => $providerName], 'id ASC', '*', 0, 1);
    if ($matches) {
        $existingProvider = reset($matches);
    }

    if ($usecore) {
        // Core reads the credentials as apikey/apisecret and takes the region from each
        // action's settings, not from the instance config: see
        // aiprovider_awsbedrock\provider::create_bedrock_client() and
        // aiprovider_awsbedrock\abstract_processor::get_region().
        $config = [
            'apikey' => $accessKeyId,
            'apisecret' => $secretAccessKey,
        ];

        // Anything left in settings beyond model, awsregion, cross_region_inference,
        // systeminstruction, providerid and modelextraparams is passed to Bedrock as a model
        // parameter (abstract_processor::get_model_settings() unsets only those six), so do
        // not add anything else here.
        //
        // systeminstruction is mandatory: process_generate_text::get_system_instruction()
        // reads it straight out of the action settings with no fallback and is typed to
        // return string, so a missing key is a TypeError at request time rather than a
        // validation error. The settings form defaults it to the action's own instruction,
        // so use the same source.
        $actionconfig = [];
        foreach (
            [
                'core_ai\\aiactions\\generate_text' => $modelId,
                'core_ai\\aiactions\\summarise_text' => $modelId,
                'core_ai\\aiactions\\explain_text' => $modelId,
                'core_ai\\aiactions\\generate_image' => $imageModelId,
            ] as $action => $actionmodel
        ) {
            $settings = [
                'model' => $actionmodel,
                'awsregion' => $region,
                'systeminstruction' => $action::get_system_instruction(),
            ];

            if ($actionmodel !== $imageModelId) {
                $settings['modelextraparams'] = $textextraparams;
            }

            $actionconfig[$action] = [
                'enabled' => true,
                'settings' => $settings,
            ];
        }

        if (!empty($sessionToken)) {
            cli_writeln("Warning: AWS_SESSION_TOKEN is set but core aiprovider_awsbedrock " .
                "cannot send one (bedrock_client_factory::create_client() takes only a key " .
                "and secret). Temporary credentials will be rejected by Bedrock at request " .
                "time; use long-lived IAM keys for AI features on this instance.");
        }
    } else {
        // A session token is optional here: aiprovider_bedrock adds it to the client credentials
        // only when it is set (abstract_processor line 49), so long-lived IAM keys work too.
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
        // Only set model and modelextraparams - Moodle will use default system instructions
        $actionconfig = [
            'core_ai\\aiactions\\generate_text' => [
                'enabled' => true,
                'settings' => [
                    'model' => $modelId,
                    'modelextraparams' => $textextraparams
                ]
            ],
            'core_ai\\aiactions\\summarise_text' => [
                'enabled' => true,
                'settings' => [
                    'model' => $modelId,
                    'modelextraparams' => $textextraparams
                ]
            ],
            'core_ai\\aiactions\\explain_text' => [
                'enabled' => true,
                'settings' => [
                    'model' => $modelId,
                    'modelextraparams' => $textextraparams
                ]
            ],
            'core_ai\\aiactions\\generate_image' => [
                'enabled' => true,
                'settings' => [
                    'model' => $imageModelId
                ]
            ]
        ];
    }

    if ($existingProvider) {
        // Update existing provider
        if (!$usecore) {
            $config['updateandreturn'] = 'Update instance';
            $config['returnurl'] = 'https://' . $_SERVER['HTTP_HOST'] . '/admin/settings.php?section=aiprovider';
            $config['id'] = $existingProvider->id;
        }

        // Add providerid to actionconfig settings
        foreach ($actionconfig as $action => &$actiondata) {
            if (isset($actiondata['settings'])) {
                $actiondata['settings']['providerid'] = $existingProvider->id;
            }
        }

        // Repoint the row if it was seeded against the other plugin.
        $existingProvider->provider = $plugin . '\\provider';
        $existingProvider->config = json_encode($config);
        $existingProvider->actionconfig = json_encode($actionconfig);
        $existingProvider->enabled = 1;

        $DB->update_record('ai_providers', $existingProvider);
        cli_writeln("Updated existing AI provider (ID: {$existingProvider->id})");
    } else {
        // Create new provider
        if (!$usecore) {
            $config['createandreturn'] = 'Create instance';
            $config['returnurl'] = 'https://' . $_SERVER['HTTP_HOST'] . '/admin/settings.php?section=aiprovider';
        }

        $record = new stdClass();
        $record->name = $providerName;
        $record->provider = $plugin . '\\provider';
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
    cli_writeln("  - Provider Plugin: {$plugin}");
    cli_writeln("  - Region: {$region}");
    cli_writeln("  - Model: {$modelId}");
    cli_writeln("  - Image Model: {$imageModelId}");
    cli_writeln("  - Access Key ID: " . substr($accessKeyId, 0, 8) . "...");
    cli_writeln("  - Actions configured: generate_text, summarise_text, explain_text, generate_image");

    // Purge caches
    if (class_exists('\\cache_helper')) {
        \cache_helper::purge_all();
        cli_writeln("Purged caches.");
    }
}
