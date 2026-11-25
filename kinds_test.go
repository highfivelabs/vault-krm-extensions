// Copyright 2026 High Five Labs
// SPDX-License-Identifier: Apache-2.0

package extensions

import (
	"testing"

	"github.com/highfivelabs/krm-rest-runtime/kindtest"
)

// Every kind, against the fake API built from types.yaml: create, update,
// drift repair, delete. It proves the descriptors and the controller agree;
// it does not prove Vault's API behaves as the descriptors say.
func TestEveryKindOnFake(t *testing.T) {
	kindtest.EveryKind(t, Types, Vendor, nil)
}
