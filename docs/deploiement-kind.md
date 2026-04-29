# Déploiement local sur kind

## Objectif

Déployer une plateforme locale `AlgoHive` avec IAM et supervision sur un cluster `kind`.

## Composants attendus

- `AlgoHive-Client`
- `AlgoHive-API`
- `PostgreSQL`
- `Redis`
- `Keycloak`
- `Prometheus`
- `Grafana`
- `KubeView`

## Pré-requis

- `docker`
- `kubectl`
- `kind`

## Fichiers d'infrastructure

Cette documentation s'appuie sur une structure de travail du type:

```text
deploy/
├── bootstrap-kind.sh
├── kind/
│   └── cluster.yaml
└── k8s/
    ├── 00-namespaces.yaml
    ├── 01-algohive.yaml
    ├── 02-keycloak.yaml
    ├── 03-monitoring.yaml
    └── kustomization.yaml
```

## Étapes

### 1. Créer le cluster kind

```bash
kind create cluster --name algohive --config deploy/kind/cluster.yaml
```

### 2. Installer ingress-nginx

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/kind/deploy.yaml
kubectl wait \
  --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s
```

### 3. Construire et charger les images locales

```bash
docker build -t algohive-api:kind app-api
docker build \
  -t algohive-client:kind \
  --build-arg VITE_API_ENDPOINT=http://algohive.local/api/v1 \
  --build-arg VITE_WS_ENDPOINT=ws://algohive.local/api/v1/competitions \
  app-client
docker build -t algohive-keycloak:kind keycloak-stack

kind load docker-image algohive-api:kind --name algohive
kind load docker-image algohive-client:kind --name algohive
kind load docker-image algohive-keycloak:kind --name algohive
```

### 4. Déployer les manifests

```bash
kubectl apply -k deploy/k8s
```

### 5. Ajouter les hôtes locaux

```text
127.0.0.1 algohive.local
127.0.0.1 keycloak.algohive.local
127.0.0.1 grafana.algohive.local
127.0.0.1 prometheus.algohive.local
127.0.0.1 kubeview.algohive.local
```

## URLs attendues

- `http://algohive.local`
- `http://algohive.local/swagger/index.html`
- `http://keycloak.algohive.local/admin`
- `http://grafana.algohive.local`
- `http://prometheus.algohive.local`
- `http://kubeview.algohive.local`

## Comptes de démonstration

### Keycloak

- utilisateur: `admin`
- mot de passe: `ChangeMeKeycloakAdmin123!`

### Grafana local

- utilisateur: `admin`
- mot de passe: `ChangeMeGrafanaAdmin123!`

### Grafana via Keycloak

- utilisateur: `grafana-admin`
- mot de passe: `ChangeMeGrafanaUser123!`

## Supervision attendue

Prometheus collecte:

- métriques `AlgoHive-API`
- métriques `Keycloak`
- métriques `Redis exporter`
- métriques `Postgres exporter`

Grafana fournit:

- datasource `Prometheus`
- dashboard de synthèse
- SSO `Keycloak`

## Évolutions recommandées

1. Ajouter des `PersistentVolumeClaim`
2. Remplacer les secrets de démonstration
3. Intégrer `AlgoHive` en OIDC
4. Ajouter `Alertmanager`
5. Ajouter une chaîne GitOps
