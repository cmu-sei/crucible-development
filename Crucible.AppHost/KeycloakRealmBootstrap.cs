// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

using System.Text.Json.Nodes;

/// <summary>
/// What Keycloak's own realm import creates on an empty database: the realm and each seed user's ID
/// and username. keycloak-config-cli can't create users with fixed IDs (it uses the admin API, which
/// ignores them), and the apps and test data refer to the seed users by ID. Everything else, the
/// users' profiles, passwords, roles and groups included, comes from keycloak-config-cli, which finds
/// these users by username.
/// </summary>
internal static class KeycloakRealmBootstrap
{
    /// <summary>
    /// Writes the bootstrap import for <paramref name="realmFile"/> to <paramref name="outputDirectory"/>
    /// and returns its path.
    /// </summary>
    public static string Write(string realmFile, string outputDirectory)
    {
        var realm = JsonNode.Parse(File.ReadAllText(realmFile))!.AsObject();

        var users = new JsonArray();
        foreach (var user in realm["users"]?.AsArray() ?? [])
        {
            // Service-account users have no fixed ID; Keycloak creates them with their clients
            if (user?["id"] is null)
            {
                continue;
            }

            users.Add(new JsonObject
            {
                ["id"] = user["id"]!.DeepClone(),
                ["username"] = user["username"]?.DeepClone(),
                // The admin API grants the default role to every new user, but an import only grants
                // the roles it lists, and keycloak-config-cli never adds this one
                ["realmRoles"] = new JsonArray($"default-roles-{realm["realm"]}"),
            });
        }

        var bootstrap = new JsonObject
        {
            ["realm"] = realm["realm"]?.DeepClone(),
            ["enabled"] = true,
            ["users"] = users,
        };

        Directory.CreateDirectory(outputDirectory);
        var path = Path.Combine(outputDirectory, Path.GetFileName(realmFile));
        File.WriteAllText(path, bootstrap.ToJsonString());
        return path;
    }
}
