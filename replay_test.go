// Copyright 2026 High Five Labs
// SPDX-License-Identifier: Apache-2.0

package extensions

import (
	"testing"

	"github.com/highfivelabs/krm-rest-runtime/kindtest"
)

// The live steps of every kind in hack/live/live.yaml, against what
// Vault answered in the last passing live run (hack/live/cassettes):
// no network, no credentials, no build tag. A kind skips until a live run
// has recorded it. How it works: krm-rest-runtime docs/live.md "Replay".
func TestEveryKindReplay(t *testing.T) {
	kindtest.Replay(t, Types, Vendor, nil, liveYAML)
}
