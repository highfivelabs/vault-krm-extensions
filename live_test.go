// Copyright 2026 High Five Labs
// SPDX-License-Identifier: Apache-2.0

//go:build live

package extensions

import (
	"testing"

	"github.com/highfivelabs/krm-rest-runtime/kindtest"
)

// The kinds hack/live/live.yaml lists, against a real Vault: create,
// update, drift repair, delete. Compiled only with -tags live, and skips,
// saying why, unless KRM_LIVE=1 and credentials are found (task live:vault
// starts a dev server in kind and runs this). Results go to
// hack/live/records.json, which sets each kind's readiness.
func TestEveryKindLive(t *testing.T) {
	kindtest.Live(t, Types, Vendor, nil, liveYAML)
}

// Deletes every live-test leftover (KRM_LIVE=1 KRM_LIVE_SWEEP=1).
func TestLiveSweep(t *testing.T) {
	kindtest.LiveSweep(t, Vendor, liveYAML)
}
