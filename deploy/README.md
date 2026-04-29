# Déploiement inclus

Ce dépôt contient la base d'infrastructure nécessaire pour lancer `AlgoHive` sur `kind` avec:

- `AlgoHive-Client`
- `AlgoHive-API`
- `Keycloak`
- `Prometheus`
- `Grafana`
- `KubeView`

## Contenu

```text
deploy/
├── README.md
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

## Sources attendues

Le script cherche automatiquement les dépôts sources dans l'un des emplacements suivants:

- `../app-api` ou `../AlgoHive-API`
- `../app-client` ou `../AlgoHive-Client`
- `../keycloak-stack` ou `../Keycloak`

Vous pouvez aussi forcer les chemins:

```bash
export ALGOHIVE_API_DIR=/chemin/vers/AlgoHive-API
export ALGOHIVE_CLIENT_DIR=/chemin/vers/AlgoHive-Client
export ALGOHIVE_KEYCLOAK_DIR=/chemin/vers/Keycloak
./deploy/bootstrap-kind.sh
```

## URL supplémentaire

- `http://kubeview.algohive.local`
