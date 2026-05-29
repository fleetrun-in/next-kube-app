#!/usr/bin/env bash
set -euo pipefail

: "${IMAGE:?IMAGE is required}"
: "${INGRESS_HOST:?INGRESS_HOST is required}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${OUT_DIR:-/tmp/next-kube-app-k8s}"

mkdir -p "${OUT_DIR}"

for manifest in namespace deployment service ingress; do
  envsubst '${IMAGE} ${INGRESS_HOST}' < "${ROOT_DIR}/k8s/${manifest}.yaml" > "${OUT_DIR}/${manifest}.yaml"
done

if [[ -n "${DOCKER_CONFIG_JSON_B64:-}" ]]; then
  envsubst '${DOCKER_CONFIG_JSON_B64}' < "${ROOT_DIR}/k8s/imagepullsecret.yaml" > "${OUT_DIR}/imagepullsecret.yaml"
fi

echo "Rendered manifests in ${OUT_DIR}"
