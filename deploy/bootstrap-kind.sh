#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-algohive}"
INGRESS_MANIFEST="https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/kind/deploy.yaml"

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Commande requise introuvable: $1" >&2
    exit 1
  fi
}

first_existing_dir() {
  for candidate in "$@"; do
    if [ -n "${candidate}" ] && [ -d "${candidate}" ]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  return 1
}

require docker
require kind
require kubectl

API_DIR="${ALGOHIVE_API_DIR:-}"
CLIENT_DIR="${ALGOHIVE_CLIENT_DIR:-}"
KEYCLOAK_DIR="${ALGOHIVE_KEYCLOAK_DIR:-}"

if [ -z "${API_DIR}" ]; then
  API_DIR="$(first_existing_dir "${ROOT_DIR}/../app-api" "${ROOT_DIR}/../AlgoHive-API" || true)"
fi
if [ -z "${CLIENT_DIR}" ]; then
  CLIENT_DIR="$(first_existing_dir "${ROOT_DIR}/../app-client" "${ROOT_DIR}/../AlgoHive-Client" || true)"
fi
if [ -z "${KEYCLOAK_DIR}" ]; then
  KEYCLOAK_DIR="$(first_existing_dir "${ROOT_DIR}/../keycloak-stack" "${ROOT_DIR}/../Keycloak" || true)"
fi

if [ -z "${API_DIR}" ] || [ ! -d "${API_DIR}" ]; then
  echo "Repo API introuvable. Definissez ALGOHIVE_API_DIR." >&2
  exit 1
fi
if [ -z "${CLIENT_DIR}" ] || [ ! -d "${CLIENT_DIR}" ]; then
  echo "Repo Client introuvable. Definissez ALGOHIVE_CLIENT_DIR." >&2
  exit 1
fi
if [ -z "${KEYCLOAK_DIR}" ] || [ ! -d "${KEYCLOAK_DIR}" ]; then
  echo "Repo Keycloak introuvable. Definissez ALGOHIVE_KEYCLOAK_DIR." >&2
  exit 1
fi

echo "API_DIR=${API_DIR}"
echo "CLIENT_DIR=${CLIENT_DIR}"
echo "KEYCLOAK_DIR=${KEYCLOAK_DIR}"

if ! kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  echo "Creation du cluster kind ${CLUSTER_NAME}"
  kind create cluster --name "${CLUSTER_NAME}" --config "${ROOT_DIR}/deploy/kind/cluster.yaml"
else
  echo "Le cluster kind ${CLUSTER_NAME} existe deja"
fi

echo "Installation de ingress-nginx"
kubectl apply -f "${INGRESS_MANIFEST}"
kubectl wait \
  --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

echo "Build des images locales"
docker build -t algohive-api:kind "${API_DIR}"
docker build \
  -t algohive-client:kind \
  --build-arg VITE_API_ENDPOINT=http://algohive.local/api/v1 \
  --build-arg VITE_WS_ENDPOINT=ws://algohive.local/api/v1/competitions \
  "${CLIENT_DIR}"
docker build -t algohive-keycloak:kind "${KEYCLOAK_DIR}"

echo "Chargement des images dans kind"
kind load docker-image algohive-api:kind --name "${CLUSTER_NAME}"
kind load docker-image algohive-client:kind --name "${CLUSTER_NAME}"
kind load docker-image algohive-keycloak:kind --name "${CLUSTER_NAME}"

echo "Application des manifests Kubernetes"
kubectl apply -k "${ROOT_DIR}/deploy/k8s"

echo "Attente des deploiements"
kubectl rollout status deployment/algohive-postgres -n algohive --timeout=180s
kubectl rollout status deployment/algohive-redis -n algohive --timeout=180s
kubectl rollout status deployment/algohive-api -n algohive --timeout=180s
kubectl rollout status deployment/algohive-client -n algohive --timeout=180s
kubectl rollout status deployment/keycloak-postgres -n algohive --timeout=180s
kubectl rollout status deployment/keycloak -n algohive --timeout=240s
kubectl rollout status deployment/prometheus -n monitoring --timeout=180s
kubectl rollout status deployment/grafana -n monitoring --timeout=180s

cat <<'EOF'

Stack prete.

Ajoutez ces entrees dans /etc/hosts si ce n'est pas deja fait:
127.0.0.1 algohive.local
127.0.0.1 keycloak.algohive.local
127.0.0.1 grafana.algohive.local
127.0.0.1 prometheus.algohive.local

Acces:
- http://algohive.local
- http://algohive.local/swagger/index.html
- http://keycloak.algohive.local/admin
- http://grafana.algohive.local
- http://prometheus.algohive.local
EOF
