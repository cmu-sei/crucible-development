# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Project Overview

Crucible Development is a Development Container and .NET Aspire orchestration environment for the Crucible platform - a cybersecurity training and simulation platform developed by Carnegie Mellon University's Software Engineering Institute (SEI).

This is a **meta-repository** that orchestrates 30+ external repositories cloned into `/mnt/data/crucible/`. The main orchestrator (`Crucible.AppHost`) manages all microservices using .NET Aspire.

## General recommendations for working with Aspire

1. Before making any changes always run the apphost using `aspire run` and inspect the state of resources to make sure you are building from a known state.
2. Changes to the _AppHost.cs_ file will require a restart of the application to take effect.
3. Make changes incrementally and run the aspire application using the `aspire run` command to validate changes.
4. Use the Aspire MCP tools to check the status of resources and debug issues.

## Checking resources
To check the status of resources defined in the app model use the _list resources_ tool. This will show you the current state of each resource and if there are any issues. If a resource is not running as expected you can use the _execute resource command_ tool to restart it or perform other actions.

## Listing integrations
IMPORTANT! When a user asks you to add a resource to the app model you should first use the _list integrations_ tool to get a list of the current versions of all the available integrations. You should try to use the version of the integration which aligns with the version of the Aspire.AppHost.Sdk. Some integration versions may have a preview suffix. Once you have identified the correct integration you should always use the _get integration docs_ tool to fetch the latest documentation for the integration and follow the links to get additional guidance.

## Debugging issues
IMPORTANT! Aspire is designed to capture rich logs and telemetry for all resources defined in the app model. Use the following diagnostic tools when debugging issues with the application before making changes to make sure you are focusing on the right things.

1. _list structured logs_; use this tool to get details about structured logs.
2. _list console logs_; use this tool to get details about console logs.
3. _list traces_; use this tool to get details about traces.
4. _list trace structured logs_; use this tool to get logs related to a trace

## Playwright MCP server
The playwright MCP server has also been configured in this repository and you should use it to perform functional investigations of the resources defined in the app model as you work on the codebase. To get endpoints that can be used for navigation using the playwright MCP server use the list resources tool.

## Playwright Test Suite
End-to-end Playwright tests live at `/mnt/data/crucible/crucible-tests/`. This repo contains test plans and spec files for all 11 Crucible applications. See the `README.md` in that directory for full details on test conventions, fixtures, and how to write/run tests. When asked to create, update, or run Playwright tests, work in that directory.

## Aspire workload
IMPORTANT! The aspire workload is obsolete. You should never attempt to install or use the Aspire workload.

## Official documentation
IMPORTANT! Always prefer official documentation when available. The following sites contain the official documentation for Aspire and related components

1. https://aspire.dev
2. https://learn.microsoft.com/dotnet/aspire
3. https://nuget.org (for specific integration package details)

## Code Design Specifications
The `design-specs` folder houses documents outlining coding best practices and design specifications for Crucible apps to follow. Review `design-specs/README.md` for high level overviews of the specifications. Then, if doing development that targets an area with a design specification, read that specification and follow it when coding.
