#!/usr/bin/env bash
# Copyright 2026 High Five Labs
# SPDX-License-Identifier: Apache-2.0
# Download the vendor's OpenAPI specs at the commits vendor.yaml pins.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p specs
[ -s specs/vault.json ] || curl -fsSL -o specs/vault.json "https://raw.githubusercontent.com/hashicorp/vault-client-go/a0f17ccb92501f7b7ad1bf5188b404383f08a45f/openapi.json"
