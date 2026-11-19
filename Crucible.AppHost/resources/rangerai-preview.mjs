// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

import { readFileSync } from "node:fs";

export default {
  build: { outDir: "dist/ui/browser" },
  preview: {
    host: "0.0.0.0",
    strictPort: true,
    proxy: JSON.parse(readFileSync("proxy.conf.json", "utf8")),
  },
};
