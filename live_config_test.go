// Copyright 2026 High Five Labs
// SPDX-License-Identifier: Apache-2.0

package extensions

import (
	_ "embed"
	"testing"

	"github.com/highfivelabs/krm-rest-runtime/kindtest"
)

//go:embed hack/live/live.yaml
var liveYAML []byte

// hack/live/live.yaml parses and lists only kinds types.yaml has. This runs
// in go test ./... and reaches nothing; the live tests are in live_test.go.
func TestLiveConfig(t *testing.T) {
	kindtest.ValidLiveConfig(t, Types, liveYAML)
}
