// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

// TEMPLATE INSTRUCTIONS: delete this paragraph in the repo copy (a short
// comment saying what is app-specific may replace it). APP-SPECIFIC. Rename to
// mock-permission-data.service.ts and adapt the generated permission services
// and claim types to this app. Keep the shape: a `PermissionGrants` input,
// `permissionApiStubs(grants)`, and `permissionDataProviders(grants)` that
// provides the app's REAL permission service over stubbed "my permissions"
// endpoints. The gate logic under test is then the production code, not a
// re-implementation that can drift from it. sync.sh checks that the three
// exports exist.
//
// The factory primes the permission streams, because most components read
// permissions that the app shell loaded. A component that triggers the load
// itself (calls `load()` in ngOnInit) is tested without the factory: provide
// the `permissionApiStubs(grants)` services plus the plain permission service
// class, and assert that the "my permissions" endpoint was called.

import { inject, Provider } from '@angular/core';
import { vi } from 'vitest';
import { of } from 'rxjs';
// import { SystemPermission, SystemPermissionsService, ... } from '../generated/<app>-api';
// import { PermissionDataService } from '../data/permission/permission-data.service';
import { ApiStub } from './api-stub';

export interface PermissionGrants {
  // system?: SystemPermission[];
  // <entity>?: <Entity>PermissionClaim[];
}

export function permissionApiStubs(grants: PermissionGrants = {}) {
  return {
    // systemPermissions: {
    //   getMySystemPermissions: vi.fn(() => of(grants.system ?? [])),
    // } satisfies ApiStub<SystemPermissionsService>,
  };
}

export function permissionDataProviders(
  grants: PermissionGrants = {},
): Provider[] {
  const stubs = permissionApiStubs(grants);
  return [
    // { provide: SystemPermissionsService, useValue: stubs.systemPermissions },
    // {
    //   provide: PermissionDataService,
    //   // inject() resolves the stubs above (or a test's own override) with the
    //   // real types, so the partial stubs need no casts.
    //   useFactory: () => {
    //     // Constructor injection: pass the injected stubs in constructor order.
    //     // A service that uses `inject()` fields instead is built with a bare
    //     // `new PermissionDataService()`; useFactory runs in an injection context.
    //     const service = new PermissionDataService(inject(SystemPermissionsService) /* ...in constructor order */);
    //     service.load().subscribe();   // or whatever primes the permission streams
    //     return service;
    //   },
    // },
  ];
}
