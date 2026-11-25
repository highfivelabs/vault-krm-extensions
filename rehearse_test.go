// Copyright 2026 High Five Labs
// SPDX-License-Identifier: Apache-2.0

package extensions

import (
	"testing"

	"github.com/highfivelabs/krm-rest-runtime/kindtest"
)

// Every kind's live steps against the runtime's fake API: the kinds in
// hack/live/live.yaml with their live specs, the rest with their samples,
// replayed from hack/fake/cassettes (KRM_FAKE_RECORD=1 records them again).
// A full request and response example of every kind; nothing about the real
// API. How it works: krm-rest-runtime docs/live.md "Rehearsal".
func TestEveryKindRehearsal(t *testing.T) {
	kindtest.Rehearse(t, Types, Vendor, nil, liveYAML)
}
