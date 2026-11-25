// Copyright 2026 High Five Labs
// SPDX-License-Identifier: Apache-2.0

package extensions

import (
	"testing"

	"github.com/highfivelabs/krm-rest-runtime/kindtest"
)

func TestCRDsAreValid(t *testing.T) { kindtest.ValidCRDs(t, "config/crds") }

// Every kind's sample and live spec is one the API server would accept:
// the fake and live tests run on an in-memory Kubernetes that checks no
// schema.
func TestExamplesMatchCRDs(t *testing.T) { kindtest.ValidExamples(t, Types, liveYAML, "config/crds") }
