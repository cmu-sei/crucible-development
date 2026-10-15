// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

// TEMPLATE INSTRUCTIONS: delete this paragraph in the repo copy (a short
// comment saying what is app-specific may replace it). One of the two
// app-specific helpers. Rename to default-test-providers.ts and fill in the
// numbered blocks from this app's own code. Keep the structure and the
// section order, so the file reads the same in every Crucible UI; the numbered
// comments may stay. sync.sh checks that every provider and stub member below
// is still present in the repo copy (extra ones are fine).

import { EMPTY, of } from 'rxjs';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { ActivatedRoute, convertToParamMap } from '@angular/router';
import {
  ComnAuthQuery,
  ComnAuthService,
  ComnSettingsService,
} from '@cmusei/crucible-common';
import { AnyProvider, mergeProviders, unstubbed } from './unstubbed';

// 1. App services that components inject (SignalR, error, dialog, system
//    message, xAPI, ...) as `unstubbed(...)` placeholders. State stays REAL and
//    is not listed here: Akita stores, queries and data services, and
//    non-Akita state services that hold app state in BehaviorSubjects (player
//    and vm data services). Two exceptions:
//    - A state service provided in an NgModule's or component's `providers`
//      rather than `providedIn: 'root'` is listed as its real class
//      (`XStateService,`), so the TestBed can build it.
//    - A data service whose constructor reads router state
//      (`router.routerState.snapshot`) or otherwise fails without navigation
//      gets an `unstubbed(...)` placeholder. Its own spec uses the real
//      service under `RouterTestingHarness`; component specs pass a typed
//      stub (`satisfies Pick<XDataService, ...>`) and assert every call the
//      component makes on it.
//    A service that wraps an external runtime rather than holding state (a
//    hub connection, the WMKS console, a browser API) is an edge: placeholder
//    here, typed stub in component specs.
// import { SignalRService } from '../services/signalr/signalr.service';

// 2. Every generated API service that src/app/generated/<app>-api/api.ts
//    exports (stale files in that folder that api.ts does not export are
//    skipped).
// import { ... } from '../generated/<app>-api';

// 3. RouterQuery, only if the app uses @datorama/akita-ng-router-store.
// import { RouterQuery } from '@datorama/akita-ng-router-store';

// 4. The generated client's BASE_PATH token, if data or hub services inject it.
// import { BASE_PATH } from '../generated/<app>-api';
// export const TEST_BASE_PATH = 'http://test-api';

// 5. Every other common-library service the app injects (CrucibleDialogService,
//    CrucibleThemeService, ComnAuthGuardService, ...), as an `unstubbed(...)`
//    placeholder under "Common library" below. They are `providedIn: 'root'`,
//    so one left out is not an error: the REAL service is built and leaks into
//    specs (real dialogs, real theme writes). sync.sh checks that every
//    `*Service` / `*Query` imported from @cmusei/crucible-common in src/app is
//    listed in this file.

export function getDefaultProviders(
  overrides?: readonly AnyProvider[],
): AnyProvider[] {
  const defaults: AnyProvider[] = [
    // App services
    // unstubbed(SignalRService),
    // { provide: ErrorService, useValue: { handleError: () => {} } },

    // Generated API services: one `unstubbed(...)` per service. A test that
    // needs an endpoint passes `{ provide: XService, useValue: xApi }` built
    // with `satisfies ApiStub<XService>`.

    // Akita router (only if used). List the members this app's components call.
    // {
    //   provide: RouterQuery,
    //   useValue: {
    //     select: () => of(null),
    //     selectParams: () => of(null),
    //     selectQueryParams: () => of(null),
    //     getParams: () => null,
    //     getQueryParams: () => null,
    //   },
    // },

    // Generated client base path (only if injected)
    // { provide: BASE_PATH, useValue: TEST_BASE_PATH },

    // Common library
    {
      provide: ComnSettingsService,
      useValue: {
        settings: {
          // 6. The keys this app reads from settings.json, with neutral values
          //    (ApiUrl, ConsoleApiUrl, Hotkeys, ...).
          ApiUrl: '',
          AppTopBarText: '',
          AppTopBarHexColor: '#000000',
          AppTopBarHexTextColor: '#FFFFFF',
        },
      },
    },
    {
      provide: ComnAuthService,
      useValue: {
        isAuthenticated$: of(true),
        // Use `of({ profile: { sub: '' } })` if the app reads user.profile.
        user$: of({}),
        logout: () => {},
        // Add members this app's components call (setUserTheme, ...). Keep the
        // defaults minimal; a spec that needs more passes its own stub.
      },
    },
    {
      provide: ComnAuthQuery,
      useValue: {
        userTheme$: of('light-theme'),
        isLoggedIn$: of(true),
      },
    },

    // Dialog tokens
    { provide: MAT_DIALOG_DATA, useValue: {} },
    {
      provide: MatDialogRef,
      useValue: {
        close: () => {},
        beforeClosed: () => EMPTY,
        afterClosed: () => EMPTY,
        keydownEvents: () => EMPTY,
      },
    },

    // Router
    {
      provide: ActivatedRoute,
      useValue: {
        params: of({}),
        paramMap: of(convertToParamMap({})),
        queryParams: of({}),
        queryParamMap: of(convertToParamMap({})),
        snapshot: {
          params: {},
          paramMap: convertToParamMap({}),
          queryParams: {},
          queryParamMap: convertToParamMap({}),
        },
      },
    },
  ];

  return mergeProviders(defaults, overrides);
}
