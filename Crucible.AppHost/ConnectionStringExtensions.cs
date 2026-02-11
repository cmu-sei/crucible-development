// Copyright 2025 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

public static class ConnectionStringExtensions
{
    /// <summary>
    /// Append common dev settings to the connection string of a postgres database. e.g. "Include Error Detail=true".
    /// </summary>
    /// <param name="database">The postgres database whose connection string will be appended to</param>
    /// <returns>An IResourceWithConnectionString, rather than the original IResourceBuilder PostgresDatabaseResource.
    /// If the caller needs any specific properties of the original resource beyond those available in the IResourceWithConnectionString interface,
    /// they may need to be added to the AppendConnectionStringResource.</returns>
    public static IResourceBuilder<IResourceWithConnectionString> WithDevSettings(this IResourceBuilder<PostgresDatabaseResource> database)
    {
        return database.AddConnectionStringData($"Include Error Detail=True");
    }

    // Adapted from https://github.com/dotnet/aspire/discussions/3605#discussioncomment-9090161
    // Adds a custom resource that appends to another resource's connection string
    public static IResourceBuilder<IResourceWithConnectionString> AddConnectionStringData(this IResourceBuilder<IResourceWithConnectionString> builder, ReferenceExpression.ExpressionInterpolatedStringHandler connectionStringData)
    {
        return builder.ApplicationBuilder.AddResource(new AppendConnectionStringResource(builder.Resource, ReferenceExpression.Create(connectionStringData)))
            .WithInitialState(new CustomResourceSnapshot
            {
                Properties = [],
                ResourceType = "ConnectionStringData",
                State = "Hidden" // Hide from the dashboard
            });
    }

    class AppendConnectionStringResource(IResourceWithConnectionString previous, ReferenceExpression referenceExpression) :
        Resource($"{previous.Name}-ConnectionString"), IResourceWithConnectionString
    {
        public string? ConnectionStringEnvironmentVariable => previous.ConnectionStringEnvironmentVariable;

        public ReferenceExpression ConnectionStringExpression => ReferenceExpression.Create($"{previous};{referenceExpression}");
    }
}
