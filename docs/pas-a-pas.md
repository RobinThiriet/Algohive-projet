# Documentation pas-a-pas

## But

Mettre en place une plateforme `AlgoHive` locale sur `kind` avec:

- interface web
- API
- base de données
- cache Redis
- `Keycloak`
- `Prometheus`
- `Grafana`

Cette documentation est volontairement très guidée.

## Résultat attendu

À la fin, vous devez pouvoir ouvrir:

- `http://algohive.local`
- `http://algohive.local/swagger/index.html`
- `http://keycloak.algohive.local/admin`
- `http://grafana.algohive.local`
- `http://prometheus.algohive.local`

## Étape 1. Préparer la machine

Vérifier que les outils nécessaires sont installés:

```bash
docker --version
kubectl version --client
kind --version
git --version
```

Si une de ces commandes échoue, il faut installer l'outil manquant avant d'aller plus loin.

## Étape 2. Récupérer les dépôts utiles

Créer un dossier de travail puis cloner les dépôts:

```bash
git clone https://github.com/AlgoHive-Coding-Puzzles/AlgoHive-Client
git clone https://github.com/AlgoHive-Coding-Puzzles/AlgoHive-API
git clone https://github.com/RobinThiriet/Keycloak
git clone https://github.com/RobinThiriet/Algohive-projet
```

Vous devez ensuite obtenir une arborescence proche de:

```text
workspace/
├── AlgoHive-API/
├── AlgoHive-Client/
├── Keycloak/
└── Algohive-projet/
```

## Étape 3. Préparer l'arborescence d'infrastructure

Dans le dépôt `Algohive-projet`, créer ou recopier une structure de ce type:

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

Cette structure sert à:

- créer le cluster `kind`
- builder les images locales
- déployer la stack Kubernetes

## Étape 4. Créer le cluster kind

Depuis la racine du projet:

```bash
kind create cluster --name algohive --config deploy/kind/cluster.yaml
```

Vérifier ensuite que le cluster existe:

```bash
kind get clusters
kubectl cluster-info
kubectl get nodes
```

Vous devez voir un cluster `algohive` et au moins un nœud `Ready`.

## Étape 5. Installer Ingress NGINX

Installer le contrôleur ingress:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/kind/deploy.yaml
```

Attendre qu'il soit prêt:

```bash
kubectl wait \
  --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s
```

Vérifier:

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

## Étape 6. Construire les images Docker locales

Construire l'image de l'API:

```bash
docker build -t algohive-api:kind ../AlgoHive-API
```

Construire l'image du client:

```bash
docker build \
  -t algohive-client:kind \
  --build-arg VITE_API_ENDPOINT=http://algohive.local/api/v1 \
  --build-arg VITE_WS_ENDPOINT=ws://algohive.local/api/v1/competitions \
  ../AlgoHive-Client
```

Construire l'image Keycloak:

```bash
docker build -t algohive-keycloak:kind ../Keycloak
```

Vérifier les images:

```bash
docker images | grep algohive
```

## Étape 7. Charger les images dans kind

Charger les images créées dans le cluster:

```bash
kind load docker-image algohive-api:kind --name algohive
kind load docker-image algohive-client:kind --name algohive
kind load docker-image algohive-keycloak:kind --name algohive
```

Cette étape est importante: sans elle, Kubernetes essaiera de télécharger des images qui n'existent pas dans un registre distant.

## Étape 8. Déployer les namespaces

Appliquer les namespaces:

```bash
kubectl apply -f deploy/k8s/00-namespaces.yaml
```

Vérifier:

```bash
kubectl get namespaces
```

Vous devez voir:

- `algohive`
- `monitoring`

## Étape 9. Déployer la couche AlgoHive

Déployer les composants applicatifs:

```bash
kubectl apply -f deploy/k8s/01-algohive.yaml
```

Vérifier:

```bash
kubectl get all -n algohive
```

Attendre que les pods deviennent `Running`:

```bash
kubectl get pods -n algohive -w
```

À ce stade, vous devez avoir au minimum:

- `algohive-client`
- `algohive-api`
- `algohive-postgres`
- `algohive-redis`

## Étape 10. Déployer Keycloak

Déployer la partie IAM:

```bash
kubectl apply -f deploy/k8s/02-keycloak.yaml
```

Vérifier:

```bash
kubectl get all -n algohive
kubectl logs -n algohive deployment/keycloak
```

Le déploiement installe:

- la base `PostgreSQL` dédiée à Keycloak
- le serveur `Keycloak`
- un import de realm
- un client OAuth pour Grafana

## Étape 11. Déployer le monitoring

Déployer la supervision:

```bash
kubectl apply -f deploy/k8s/03-monitoring.yaml
```

Vérifier:

```bash
kubectl get all -n monitoring
kubectl get configmap -n monitoring
kubectl get secret -n monitoring
```

À ce stade, vous devez voir:

- `prometheus`
- `grafana`
- `redis-exporter`
- `postgres-exporter-algohive`
- `postgres-exporter-keycloak`

## Étape 12. Vérifier l'ensemble du déploiement

Faire une vue d'ensemble:

```bash
kubectl get pods -A
kubectl get svc -A
kubectl get ingress -A
```

Tous les pods doivent être `Running` ou `Completed` selon les cas.

## Étape 13. Ajouter les entrées /etc/hosts

Ajouter ces lignes:

```text
127.0.0.1 algohive.local
127.0.0.1 keycloak.algohive.local
127.0.0.1 grafana.algohive.local
127.0.0.1 prometheus.algohive.local
```

Sur Linux ou macOS:

```bash
sudo nano /etc/hosts
```

Puis enregistrer le fichier.

## Étape 14. Tester les accès web

Ouvrir:

- `http://algohive.local`
- `http://algohive.local/swagger/index.html`
- `http://keycloak.algohive.local/admin`
- `http://grafana.algohive.local`
- `http://prometheus.algohive.local`

Si une URL ne répond pas:

```bash
kubectl get ingress -A
kubectl describe ingress -A
```

## Étape 15. Se connecter aux outils

### Keycloak

- utilisateur: `admin`
- mot de passe: `ChangeMeKeycloakAdmin123!`

### Grafana local

- utilisateur: `admin`
- mot de passe: `ChangeMeGrafanaAdmin123!`

### Grafana via Keycloak

- utilisateur: `grafana-admin`
- mot de passe: `ChangeMeGrafanaUser123!`

## Étape 16. Vérifier la supervision

Dans `Prometheus`, vérifier les targets.

Vous devez retrouver des jobs comme:

- `algohive-api`
- `keycloak`
- `redis-exporter`
- `postgres-exporter-algohive`
- `postgres-exporter-keycloak`

Dans `Grafana`, vérifier:

- la datasource `Prometheus`
- le dashboard `AlgoHive Overview`
- le bouton de connexion SSO `Keycloak`

## Étape 17. Vérifier les métriques API

Tester directement l'endpoint métriques:

```bash
curl http://algohive.local/api/v1/metrics
```

Tester aussi le ping API:

```bash
curl http://algohive.local/api/v1/ping
```

Vous devez obtenir une réponse JSON de type:

```json
{"message":"pong"}
```

## Étape 18. Vérifier les ressources Kubernetes

Quelques commandes utiles:

```bash
kubectl top pods -A
kubectl describe pod -n algohive <nom-du-pod>
kubectl logs -n algohive deployment/algohive-api
kubectl logs -n algohive deployment/keycloak
kubectl logs -n monitoring deployment/prometheus
kubectl logs -n monitoring deployment/grafana
```

## Dépannage

### Le client ne charge pas

Vérifier:

```bash
kubectl logs -n algohive deployment/algohive-client
kubectl get ingress -n algohive
```

### L'API ne démarre pas

Vérifier:

```bash
kubectl logs -n algohive deployment/algohive-api
kubectl get pods -n algohive
```

Causes fréquentes:

- problème de connexion PostgreSQL
- problème Redis
- variable d'environnement manquante

### Keycloak ne devient pas Ready

Vérifier:

```bash
kubectl logs -n algohive deployment/keycloak
kubectl logs -n algohive deployment/keycloak-postgres
```

Causes fréquentes:

- base Keycloak non prête
- import de realm invalide
- mauvaise configuration du port de management

### Grafana n'affiche rien

Vérifier:

```bash
kubectl logs -n monitoring deployment/grafana
kubectl logs -n monitoring deployment/prometheus
```

Puis vérifier dans Grafana:

- la datasource
- le dashboard
- les URLs OAuth

## Nettoyage

Pour supprimer le cluster:

```bash
kind delete cluster --name algohive
```

Pour supprimer seulement les workloads:

```bash
kubectl delete -k deploy/k8s
```

## Suite recommandée

Après cette mise en place, les prochaines étapes utiles sont:

1. brancher `AlgoHive` directement sur `Keycloak`
2. sécuriser les secrets
3. ajouter de la persistance
4. activer TLS
5. ajouter `Alertmanager`
