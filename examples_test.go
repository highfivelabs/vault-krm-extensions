// Copyright 2026 High Five Labs
// SPDX-License-Identifier: Apache-2.0

package extensions

import (
	"testing"

	"github.com/highfivelabs/krm-rest-runtime/kindtest"
)

// Every examples/<Kind>/*.yaml (gen/examples.py: a kind with the kinds it
// needs, joined by spec.fieldRefs) passes its CRDs, and the controllers
// make it all, a parent first, and delete it on the fake API.
func TestExampleFilesOnFake(t *testing.T) {
	kindtest.ValidExampleFiles(t, Types, Vendor, nil, "examples", "config/crds")
}
