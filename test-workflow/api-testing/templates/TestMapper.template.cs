// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

// TEMPLATE INSTRUCTIONS: delete this paragraph in the repo copy (a short comment saying what is
// app-specific may replace it). Destination: <Tests>/Support/TestMapper.cs. Mirror the app's
// AddAutoMapper call exactly: the marker type whose assembly is scanned (Startup), and every global
// convention (player.api's IgnoreNullSourceValues, applied with ForAllPropertyMaps). If a convention uses
// an internal type of the API, copy it here privately rather than adding InternalsVisibleTo, and guard the
// copy with a MappingConfigurationTests test. AutoMapper stays at 13 (licensing); do not upgrade it here.

using AutoMapper;

namespace App.Api.Tests.Support;

/// <summary>The application's real AutoMapper configuration, built without starting the application.</summary>
public static class TestMapper
{
    private static readonly Lazy<MapperConfiguration> LazyConfiguration = new(() =>
        new MapperConfiguration(cfg =>
        {
            cfg.AddMaps(typeof(App.Api.Startup).Assembly);
            // Global conventions from Startup's AddAutoMapper call go here.
        }));

    /// <summary>The shared configuration, built once for the run.</summary>
    public static MapperConfiguration Configuration => LazyConfiguration.Value;

    /// <summary>A mapper over <see cref="Configuration"/>. Thread-safe; tests share one.</summary>
    public static IMapper Mapper => LazyMapper.Value;

    private static readonly Lazy<IMapper> LazyMapper = new(() => LazyConfiguration.Value.CreateMapper());
}
