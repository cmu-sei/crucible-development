// Copyright 2025 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

/// <summary>
/// AWS credentials for containers that read the standard AWS_* variables. Moodle is the only
/// caller today; anything else that needs Bedrock or another AWS service uses the same reader.
/// </summary>
internal static class AwsCredentials
{
    /// <summary>
    /// AWS credentials for the containers (Bedrock AI on Moodle, and anything else that reads
    /// the standard AWS_* variables).
    ///
    /// Prefers the long-lived keys in ~/.aws/credentials [default] over the temporary ones in
    /// ~/.aws/sso-credentials, because Moodle 5.2's core aiprovider_awsbedrock cannot send a
    /// session token: bedrock_client_factory::create_client() takes only a key and a secret, so
    /// STS credentials come back as 403 "The security token included in the request is invalid".
    /// The SSO file is also easy to leave stale — nothing refreshes it but a manual
    /// scripts/aws-sso-login.sh run.
    /// </summary>
    internal static Dictionary<string, string>? Read()
    {
        var awsDir = Path.Combine(Environment.GetEnvironmentVariable("HOME") ?? "", ".aws");

        var creds = ReadStatic(Path.Combine(awsDir, "credentials"))
            ?? ReadSso(Path.Combine(awsDir, "sso-credentials"));

        if (creds == null)
        {
            Console.WriteLine($"No AWS credentials found in {awsDir} (looked for a [default] profile in 'credentials', then 'sso-credentials'). AWS environment variables will not be set.");
        }

        return creds;
    }

    /// <summary>
    /// Reads the [default] profile out of an AWS shared credentials (INI) file.
    /// </summary>
    private static Dictionary<string, string>? ReadStatic(string credentialsPath)
    {
        if (!File.Exists(credentialsPath))
        {
            return null;
        }

        var creds = NewCredentials();

        try
        {
            var inDefault = false;
            foreach (var rawLine in File.ReadAllLines(credentialsPath))
            {
                var line = rawLine.Trim();
                if (line.Length == 0 || line.StartsWith('#') || line.StartsWith(';'))
                {
                    continue;
                }

                if (line.StartsWith('['))
                {
                    // Only the [default] profile is used: the containers get plain AWS_* variables,
                    // with no way to say which profile they meant.
                    inDefault = line.Trim('[', ']').Trim() == "default";
                    continue;
                }

                if (!inDefault)
                {
                    continue;
                }

                var separator = line.IndexOf('=');
                if (separator < 0)
                {
                    continue;
                }

                var key = line[..separator].Trim().ToLowerInvariant();
                var value = line[(separator + 1)..].Trim();

                if (creds.ContainsKey(key))
                {
                    creds[key] = value;
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Warning: Failed to parse AWS credentials from {credentialsPath}: {ex.Message}");
            return null;
        }

        if (creds["aws_access_key_id"].Length == 0 || creds["aws_secret_access_key"].Length == 0)
        {
            return null;
        }

        Console.WriteLine($"AWS credentials loaded from the [default] profile in {credentialsPath}");
        return creds;
    }

    /// <summary>
    /// Reads the JSON that `aws configure export-credentials` writes, as produced by
    /// scripts/aws-sso-login.sh.
    /// </summary>
    private static Dictionary<string, string>? ReadSso(string credentialsPath)
    {
        if (!File.Exists(credentialsPath))
        {
            return null;
        }

        var creds = NewCredentials();

        try
        {
            var json = File.ReadAllText(credentialsPath);
            var doc = System.Text.Json.JsonDocument.Parse(json);
            var root = doc.RootElement;

            if (root.TryGetProperty("AccessKeyId", out var accessKeyId))
                creds["aws_access_key_id"] = accessKeyId.GetString() ?? "";

            if (root.TryGetProperty("SecretAccessKey", out var secretAccessKey))
                creds["aws_secret_access_key"] = secretAccessKey.GetString() ?? "";

            if (root.TryGetProperty("SessionToken", out var sessionToken))
                creds["aws_session_token"] = sessionToken.GetString() ?? "";

            if (root.TryGetProperty("Region", out var region))
                creds["region"] = region.GetString() ?? "us-east-1";

            Console.WriteLine($"AWS credentials loaded from {credentialsPath}");

            // Nothing refreshes this file automatically, and an expired token fails deep inside
            // whatever tries to use it, so say so here instead.
            if (root.TryGetProperty("Expiration", out var expiration) &&
                DateTimeOffset.TryParse(expiration.GetString(), out var expiresAt) &&
                expiresAt < DateTimeOffset.UtcNow)
            {
                Console.WriteLine($"Warning: those credentials expired at {expiresAt:u}. Run scripts/aws-sso-login.sh, or add a [default] profile with long-lived keys to ~/.aws/credentials.");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Warning: Failed to parse AWS credentials from {credentialsPath}: {ex.Message}");
            return null;
        }

        return creds;
    }

    private static Dictionary<string, string> NewCredentials() => new()
    {
        ["aws_access_key_id"] = "",
        ["aws_secret_access_key"] = "",
        ["aws_session_token"] = "",
        ["region"] = "us-east-1"
    };
}
