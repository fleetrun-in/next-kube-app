#!/usr/bin/env bash
set -euo pipefail

: "${IMAGE:?IMAGE is required}"
: "${IMAGE_LATEST:?IMAGE_LATEST is required}"
: "${GIT_SHA:?GIT_SHA is required}"
: "${INGRESS_HOST:?INGRESS_HOST is required}"
: "${HARBOR_HOST:?HARBOR_HOST is required}"
: "${HARBOR_IP:?HARBOR_IP is required}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${OUT_DIR:-/tmp/next-kube-app-k8s}"

mkdir -p "${OUT_DIR}"

for manifest in namespace deployment service ingress rbac-cd-runner kaniko-build-job; do
  if [[ "${manifest}" == "rbac-cd-runner" ]]; then
    cp "${ROOT_DIR}/k8s/${manifest}.yaml" "${OUT_DIR}/${manifest}.yaml"
  else
    envsubst '${IMAGE} ${IMAGE_LATEST} ${GIT_SHA} ${INGRESS_HOST} ${HARBOR_HOST} ${HARBOR_IP} ${APP_NAME}' < "${ROOT_DIR}/k8s/${manifest}.yaml" > "${OUT_DIR}/${manifest}.yaml"
  fi
done

if [[ -n "${DOCKER_CONFIG_JSON_B64:-}" ]]; then
  envsubst '${DOCKER_CONFIG_JSON_B64}' < "${ROOT_DIR}/k8s/imagepullsecret.yaml" > "${OUT_DIR}/imagepullsecret.yaml"
fi

echo "Rendered manifests in ${OUT_DIR}"
