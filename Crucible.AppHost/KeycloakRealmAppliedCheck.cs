// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

using Microsoft.Extensions.Diagnostics.HealthChecks;

/// <summary>
/// Healthy once the keycloak-config container has applied crucible-realm.json and exited 0.
/// Attached to Keycloak so that WaitFor(keycloak) also waits for the realm.
/// </summary>
internal sealed class KeycloakRealmAppliedCheck(ResourceNotificationService notifications, string realmConfigName) : IHealthCheck
{
    public Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        if (!notifications.TryGetCurrentState(realmConfigName, out var resourceEvent))
        {
            return Task.FromResult(HealthCheckResult.Unhealthy($"{realmConfigName} has not started"));
        }

        var snapshot = resourceEvent.Snapshot;
        var state = snapshot.State?.Text;

        if (state is null || !KnownResourceStates.TerminalStates.Contains(state))
        {
            return Task.FromResult(HealthCheckResult.Unhealthy($"{realmConfigName} is applying the realm"));
        }

        return Task.FromResult(snapshot.ExitCode == 0
            ? HealthCheckResult.Healthy()
            : HealthCheckResult.Unhealthy($"{realmConfigName} exited with code {snapshot.ExitCode?.ToString() ?? "unknown"}; see its console log"));
    }
}
