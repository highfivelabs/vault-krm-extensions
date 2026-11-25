// Copyright 2026 High Five Labs
// SPDX-License-Identifier: Apache-2.0

// Command mcp serves this repository's kinds to agents over the Model
// Context Protocol (stdio): list and describe them, get tested examples,
// check manifests against the CRDs and dry-run them against the fake API.
// Run it from the repository root, where it reads config/crds and hack/live
// (--dir to point elsewhere). Nothing it does reaches the vendor's real API.
package main

import (
	"github.com/highfivelabs/krm-rest-runtime/mcpserver"
	extensions "github.com/highfivelabs/vault-krm-extensions"
)

func main() {
	mcpserver.Main(mcpserver.Options{Vendor: extensions.Vendor, Types: extensions.Types, Hooks: nil})
}
