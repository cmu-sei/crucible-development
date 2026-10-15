// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

// TEMPLATE INSTRUCTIONS: delete this paragraph in the repo copy. The smoke
// spec is the minimum every component has (CONVENTIONS.md section 2,
// "Smoke specs"). It replaces an Angular CLI boilerplate spec at the same path
// (x.component.spec.ts beside x.component.ts) and is never a reason to leave a
// gated component without its allowed and denied cases: `check-repo.js gates`
// still fails a component that reads a permission until its spec has a denied
// case. To adapt it:
// - Rename ExampleComponent and fix the two relative imports.
// - `imports`: the Material and other modules the template uses (an NgModule
//   app renders the component outside its module; a standalone component
//   brings its own imports and needs none here).
// - Child components: an NgModule component's child elements are unknown in
//   the test module and Angular logs NG0304 through console.error, which fails
//   the test. Either declare minimal child stubs (CONVENTIONS.md section 2) or
//   pass `schemas: [CUSTOM_ELEMENTS_SCHEMA]`, which accepts unknown elements
//   with a hyphen and their bindings only. Never NO_ERRORS_SCHEMA: it also
//   hides unknown bindings on native elements (a missing matTooltip module).
//   A standalone component renders its real, imported children (or swaps them
//   with `childStubs`), and the TestBed schema does not reach its template:
//   delete the `schemas` line there.
// - `providers`: nothing, if the defaults cover what the component touches
//   while it mounts. An `unstubbed()` error names the member to stub (typed:
//   `satisfies ApiStub<S>` for a generated service, `satisfies Pick<S, ...>`
//   for an app service). An NG0201 "No provider found for X" names a token
//   the defaults leave out: use the shared stub (`bottomSheetRefStub()`,
//   `dialogRefStub()`, `activatedRouteStub()`) or a typed value.
// - Inputs the template dereferences without a guard go in `inputs`.

import { describe, it, expect } from 'vitest';
import { CUSTOM_ELEMENTS_SCHEMA } from '@angular/core';
import { renderComponent } from '../test-utils/render-component';
import { ExampleComponent } from './example.component';

describe('ExampleComponent', () => {
  /**
   * Verifies: the component mounts with the default test providers.
   * Interacts with: getDefaultProviders (placeholders and stubs only).
   * Data: no inputs beyond what the template needs to render.
   */
  it('renders with the default test providers', async () => {
    const { fixture } = await renderComponent(ExampleComponent, {
      imports: [],
      schemas: [CUSTOM_ELEMENTS_SCHEMA],
    });

    expect(fixture.componentInstance).toBeInstanceOf(ExampleComponent);
    expect(fixture.nativeElement).toBeInTheDocument();
  });
});
