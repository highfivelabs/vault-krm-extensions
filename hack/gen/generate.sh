#!/usr/bin/env bash
# Copyright 2026 High Five Labs
# SPDX-License-Identifier: Apache-2.0
# Regenerate types.yaml, config/crds and zz_generated.report.md from the
# pinned specs. RUNTIME is a krm-rest-runtime checkout (default: ../krm-rest-runtime).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd) root=$(cd "$here/../.." && pwd)
"$here/fetch-specs.sh"
python3 "${RUNTIME:-$root/../krm-rest-runtime}/gen/krmgen.py" "$here/vendor.yaml" "$root"
python3 "${RUNTIME:-$root/../krm-rest-runtime}/gen/examples.py" "$root"
