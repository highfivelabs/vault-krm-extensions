#!/usr/bin/env bash
# Copyright 2026 High Five Labs
# SPDX-License-Identifier: Apache-2.0
#
# A Vault dev server in a kind cluster: no account, no secret, a known root
# token. The live tests point at it (task live:vault); so can a person
# applying the samples by hand.
#
#   hack/live/vault-sandbox.sh up      # cluster, Vault, the samples' mounts
#   hack/live/vault-sandbox.sh creds   # the credentials JSON KRM_LIVE_CREDS takes
#   hack/live/vault-sandbox.sh run     # up, then TestEveryKindLive (-tags live)
#   hack/live/vault-sandbox.sh down    # delete the cluster
#
# Dev mode keeps everything in memory: down (or a pod restart) forgets it.
# Enterprise-only plugins (namespaces, Sentinel, MFA enforcement on Enterprise
# paths) are not in the open-source image and stay out of scope.
set -o errexit -o nounset -o pipefail
cd "$(dirname "$0")/../.."

cluster=${VAULT_SANDBOX_CLUSTER:-hfl-live-vault}
image=${VAULT_IMAGE:-hashicorp/vault:2.2.2}
port=${VAULT_PORT:-18200}
# The dev server's root token: not a secret, the server listens on 127.0.0.1
# only. Not a plain word: cassettes replace the token wherever it appears, so
# "root" would also replace the /root/ of a PKI path and namespace_id "root",
# and those calls would never replay.
token=hfl-live-dev-root-7c1e
addr="http://127.0.0.1:${port}"
ctx="kind-${cluster}"

# The mounts the generated samples name, so `kubectl apply` of a sample works
# as is. The live tests make their own per-run mounts (hack/live/live.yaml).
mounts=(
  "sys/mounts/example-kv-v1-mount-path:{\"type\":\"kv\",\"options\":{\"version\":\"1\"}}"
  "sys/mounts/example-pki-mount-path:{\"type\":\"pki\"}"
  "sys/mounts/example-transit-mount-path:{\"type\":\"transit\"}"
  "sys/auth/example-userpass-mount-path:{\"type\":\"userpass\"}"
  "sys/auth/example-aws-mount-path:{\"type\":\"aws\"}"
)

vault() { # METHOD PATH [BODY]
  curl -fsS -X "$1" -H "X-Vault-Token: ${token}" ${3:+-d "$3"} "${addr}/v1/$2"
}

up() {
  if ! kind get clusters 2>/dev/null | grep -qx "$cluster"; then
    kind create cluster --name "$cluster" --wait 120s --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - {containerPort: 30820, hostPort: ${port}, listenAddress: "127.0.0.1"}
EOF
  fi
  kubectl --context "$ctx" apply -f - >/dev/null <<EOF
apiVersion: apps/v1
kind: Deployment
metadata: {name: vault, namespace: default, labels: {app: vault}}
spec:
  replicas: 1
  selector: {matchLabels: {app: vault}}
  template:
    metadata: {labels: {app: vault}}
    spec:
      containers:
      - name: vault
        image: ${image}
        # A plugin directory holding one stand-in file, so the Plugin kind can
        # register a catalog entry (registration checks the file and its
        # SHA-256; nothing runs it until a mount uses it).
        command: [sh, -c]
        args:
        - mkdir -p /vault/plugins && printf '#!/bin/sh\\nexit 1\\n' > /vault/plugins/hfl-live-plugin &&
          chmod 755 /vault/plugins/hfl-live-plugin && exec docker-entrypoint.sh server -dev
        env:
        - {name: VAULT_LOCAL_CONFIG, value: '{"plugin_directory": "/vault/plugins"}'}
        - {name: VAULT_DEV_ROOT_TOKEN_ID, value: ${token}}
        - {name: VAULT_DEV_LISTEN_ADDRESS, value: "0.0.0.0:8200"}
        - {name: SKIP_SETCAP, value: "true"}
        ports: [{containerPort: 8200}]
        readinessProbe:
          httpGet: {path: /v1/sys/health, port: 8200}
          periodSeconds: 2
---
apiVersion: v1
kind: Service
metadata: {name: vault, namespace: default}
spec:
  type: NodePort
  selector: {app: vault}
  ports: [{port: 8200, targetPort: 8200, nodePort: 30820}]
EOF
  kubectl --context "$ctx" rollout status deploy/vault --timeout=180s >/dev/null
  for _ in $(seq 60); do
    curl -fsS "${addr}/v1/sys/health" >/dev/null 2>&1 && break
    sleep 1
  done
  curl -fsS "${addr}/v1/sys/health" >/dev/null
  local have m path body
  have=$(vault GET sys/mounts)$(vault GET sys/auth)
  for m in "${mounts[@]}"; do
    path=${m%%:*} body=${m#*:}
    grep -q "\"${path#sys/*/}/\"" <<<"$have" || vault POST "$path" "$body" >/dev/null
  done
  echo "vault: ${addr} (root token '${token}', kind context ${ctx})" >&2
}

down() {
  kind delete cluster --name "$cluster"
}

creds() {
  local adc="${GOOGLE_APPLICATION_CREDENTIALS:-$HOME/.config/gcloud/application_default_credentials.json}"
  if [[ -f "$adc" ]]; then
    python3 -c 'import json, sys; print(json.dumps({"token": sys.argv[1], "baseURL": sys.argv[2] + "/v1", "gcpCredentials": open(sys.argv[3]).read()}))' "$token" "$addr" "$adc"
  else
    printf '{"token":"%s","baseURL":"%s/v1"}\n' "$token" "$addr"
  fi
}

run() {
  up
  local status=0
  KRM_LIVE=1 KRM_LIVE_CREDS="$(creds)" \
    go test -tags live -run '^TestEveryKindLive$' -count=1 -v . "$@" || status=$?
  [[ -f hack/live/records.json ]] && cat hack/live/records.json
  return "$status"
}

case "${1:-}" in
  up) up ;;
  down) down ;;
  creds) creds ;;
  run) shift; run "$@" ;;
  *) echo "usage: $0 up|down|creds|run [go test args]" >&2; exit 2 ;;
esac
