# Spécifications


## Contexte

Vous venez d'intégrer l'équipe infrastructure de la société **Dawan**. L'équipe exploite une plateforme de services web conteneurisés, exposés via **Traefik** en reverse proxy.

Lors de vos formations précédentes, vous avez mis en place une stack de monitoring basée sur **Prometheus**, **Grafana**, **Alertmanager** et divers exporters (node_exporter, cAdvisor, process_exporter, blackbox_exporter). Vous avez également découvert les notions de **recording rules**, **alerting rules**, **remote write/read** (InfluxDB) et la **service discovery** (DNS-SD).

Votre responsable vous confie deux missions:

1. **Consolider la stack Docker Compose**: mettre en place une architecture Prometheus fédérée multi-datacenter, ajouter une application métier observable et créer un dashboard d'analyse du trafic.
2. **Adapter cette stack à Kubernetes**: déployer le monitoring via **kube-prometheus-stack** en utilisant **Helmfile**, et exploiter les CRDs de l'opérateur Prometheus.


## Prérequis

- Docker et Docker Compose installés
- Un cluster Kubernetes fonctionnel (minikube, kind ou k3d)
- `helm`, `helmfile` et le plugin `helm-diff` installés
- Connaissances acquises: Prometheus, Grafana, Alertmanager, Docker, Kubernetes, Helm


## Partie 1 — Stack Docker Compose

**Architecture cible:**

![Architecture Docker Compose — Fédération Prometheus](https://hedgedoc.dawan.fr/uploads/1b55b37a-849a-4684-9adb-c17fe4ca0060.svg)


### 1.1 — Étude comparative des architectures de scaling Prometheus

Solutions retenues:

- Prometheus Federation
- Thanos
- Cortex
- Mimir

Avant de choisir une architecture, réalisez une **étude comparative** sous forme de tableau synthétique couvrant les solutions suivantes:

| Critère                   | Fédération native | Thanos | Cortex | Mimir |
| ------------------------- | ----------------- | ------ | ------ | ----- |
| Principe                  |                   |        |        |       |
| Stockage long terme       |                   |        |        |       |
| Haute disponibilité       |                   |        |        |       |
| Déduplications            |                   |        |        |       |
| Multi-tenant              |                   |        |        |       |
| Complexité de déploiement |                   |        |        |       |
| Cas d'usage privilégié    |                   |        |        |       |

**Livrable**: un document Markdown avec le tableau rempli et une recommandation argumentée pour le contexte Dawan (3 à 5 lignes).


### 1.2 — Fédération Prometheus multi-datacenter

Dawan dispose de deux datacenters (DC01 et DC02) et d'un Prometheus central (Master) qui fédère les métriques.

**Objectif**: produire un `docker-compose.yml` pour la stack server intégrant 3 instances Prometheus en mode fédération.

**Spécifications**:

- `prometheusDC01` — scrape les exporters, simule le datacenter 1
- `prometheusDC02` — scrape les exporters, simule le datacenter 2
- `prometheusMaster` — fédère DC01 et DC02 via `/federate`

**FQDN Traefik**:

| Service           | URL                     |
| ----------------- | ----------------------- |
| Prometheus DC01   | `dc01.prom.localhost`   |
| Prometheus DC02   | `dc02.prom.localhost`   |
| Prometheus Master | `master.prom.localhost` |

**Contraintes**:

- Le Master ne scrape **aucun exporter directement**: il consomme uniquement les endpoints `/federate` de DC01 et DC02
- Chaque DC conserve une rétention courte (2h) ; le Master conserve 24h
- Les alerting rules et recording rules sont évaluées **uniquement sur le Master**
- Alertmanager reste unique et centralisé

**Indications**:

```yaml
# Extrait de configuration federation (prometheusMaster.yml)
scrape_configs:
  - job_name: "federate-dc01"
    honor_labels: true
    metrics_path: "/federate"
    params:
      "match[]":
        - '{__name__=~".+"}'
    static_configs:
      - targets: ["prometheusDC01:9090"]
```


### 1.3 — Scénarios de test de résilience

Une fois la fédération en place, validez la robustesse du dispositif en simulant les pannes suivantes:

**Scénario A — Perte d'un datacenter** :

1. Stoppez le conteneur `prometheusDC01` (`docker compose stop prometheusDC01`)
2. Vérifiez que le Master continue de recevoir les métriques de DC02
3. Observez le comportement des alertes: `CRITtargetDown` doit se déclencher pour les targets de DC01
4. Redémarrez DC01 et vérifiez la reprise

**Scénario B — Perte du Master** :

1. Stoppez le conteneur `prometheusMaster`
2. Vérifiez que DC01 et DC02 continuent de scraper et stocker localement
3. Redémarrez le Master et observez le rattrapage (ou l'absence de rattrapage)

**Livrable**: pour chaque scénario, notez vos observations (captures d'écran Grafana/Prometheus) et indiquez si des métriques ont été perdues.


### 1.4 — Bilan et limites de la fédération native

Rédigez une analyse structurée selon les axes suivants:

- **HA inter-cluster**: que se passe-t-il si le Master est indisponible ? Les alertes sont-elles toujours évaluées ?
- **Failover régional**: la fédération native propose-t-elle un mécanisme de basculement automatique ?
- **Déduplication globale**: si un même exporter est scrapé par DC01 et DC02, comment le Master gère-t-il les doublons ?
- **Scalabilité**: quelles sont les limites en nombre de séries temporelles fédérées ?

**Livrable**: document Markdown de synthèse (1 page max).


### 1.5 — Application observable avec Traefik

Pour alimenter la stack de monitoring avec du trafic applicatif réaliste, vous allez déployer une petite application derrière Traefik.

**Architecture cible**:

```
Client HTTP  -->  Traefik  -->  training-app (whoami)
                    |
                    v
               /metrics (Prometheus)
```

**Spécifications**:

Ajoutez au `docker-compose.yml` de la stack tools (ou dans un fichier dédié):

```yaml
training-app:
  image: traefik/whoami:latest
  container_name: training-app
  labels:
    - "traefik.enable=true"
    - "traefik.docker.network=traefik"
    - "traefik.http.routers.training-app.rule=Host(`app.localhost`)"
    - "traefik.http.routers.training-app.entrypoints=web"
  networks:
    - traefik
  deploy:
    replicas: 3
  restart: unless-stopped
```

**Tâches** :

1. Déployer l'application et vérifier son accès via `http://app.localhost`
2. Vérifier que Traefik expose bien les métriques du service sur son endpoint `/metrics`
3. Dans la configuration Prometheus, s'assurer que le job `traefik` scrape bien ces métriques
4. Générer du trafic avec un outil de charge:

    ```bash
    # Installer hey: go install github.com/rakyll/hey@latest
    # ou utiliser curl en boucle
    hey -n 5000 -c 50 -q 10 http://app.localhost/
    ```


### 1.6 — Recording rules et alertes pour l'application

Créez les fichiers de règles suivants dans `config/prometheus/rules/common/`:

**Recording rules** (`_rec_app.yml`) — pré-calculer les métriques clés:

- Taux de requêtes par service et par code de réponse (rate sur 5m)
- Latence p50, p90, p99 par service
- Taux d'erreur (ratio 5xx / total) par service

**Alerting rules** (`app.yml`) — détecter les anomalies:

| Alerte                  | Condition                                       | Sévérité | For |
| ----------------------- | ----------------------------------------------- | -------- | --- |
| `WARNAppHighErrorRate`  | Taux d'erreur 5xx > 5% sur 5 min                | warning  | 5m  |
| `CRITAppHighErrorRate`  | Taux d'erreur 5xx > 15% sur 5 min               | critical | 2m  |
| `WARNAppHighLatencyP99` | p99 > 800ms                                     | warning  | 5m  |
| `CRITAppServiceDown`    | Service training-app absent des targets Traefik | critical | 1m  |

**Livrable**: les deux fichiers YAML de règles.


### 1.7 — Dashboard Grafana: analyse du trafic applicatif

Créez un dashboard Grafana nommé **"Training App — Traffic Analysis"** comprenant les panels suivants:

**Ligne 1 — Vue d'ensemble** (stat panels):

- Requêtes/s actuelles
- Taux d'erreur 5xx (%)
- Latence p99 actuelle

**Ligne 2 — Tendances** (time series):

- Requêtes/s par code de réponse (200, 3xx, 4xx, 5xx) — stacked
- Distribution de latence (p50, p90, p99) sur le même graphe

**Ligne 3 — `[option]` Analyse approfondie** (table + pie chart):

- Top 10 des chemins (path) les plus appelés — table triée par volume
- Répartition des méthodes HTTP (GET, POST, PUT, DELETE) — pie chart
- Répartition des protocoles TLS utilisés (TLS 1.2, 1.3, non-TLS) — pie chart

**Ligne 4 — `[option]` Clients et sécurité** (logs + table):

- Top User-Agents (via access logs Traefik → Loki/Alloy si disponible, sinon via métriques Traefik)
- Top IP clientes par volume de requêtes

  > **Indice**: Traefik expose les métriques `traefik_service_requests_total` avec les labels `code`, `method`, `protocol`, `service`. Pour les données liées aux IPs et User-Agents, il faut exploiter les **access logs** de Traefik (format JSON) via Alloy/Promtail vers Loki, puis utiliser des requêtes LogQL dans Grafana.

**Bonus**: ajoutez une variable de dashboard `$service` de type query (label_values sur `traefik_service_requests_total`) pour filtrer dynamiquement.

**Livrable**: le dashboard exporté en JSON et placé dans `config/grafana/dashboards/app/`.


## Partie 2 — Adaptation à l'environnement Kubernetes

**Architecture cible:**

![Architecture Kubernetes — kube-prometheus-stack](https://hedgedoc.dawan.fr/uploads/e35c1a6b-ed9a-4347-adf1-66bad2c4bea0.svg)


### 2.1 — Découverte de la stack kube-prometheus-stack

Prenez connaissance du chart Helm **kube-prometheus-stack**:

- <https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack>

Ce chart déploie en une seule release:

- Prometheus (via l'opérateur)
- Alertmanager
- Grafana
- node_exporter (DaemonSet)
- kube-state-metrics
- Des dashboards et règles préconfigurés

**Tâches** :

1. Lisez la page du chart et identifiez les **composants inclus**
2. Notez les **values** les plus importantes (retention, resources, storageSpec, alertmanager.config)
3. Identifiez comment les dashboards Grafana sont provisionnés automatiquement


### 2.2 — Comprendre l'écosystème Prometheus sur Kubernetes

**L'Opérateur Prometheus**:

- <https://github.com/prometheus-operator/prometheus-operator>
- Il gère le cycle de vie des instances Prometheus, Alertmanager et ThanosRuler via des CRDs
- Il surveille les objets ServiceMonitor, PodMonitor, PrometheusRule pour configurer automatiquement le scraping et les règles

**L'Adaptateur Prometheus**:

- <https://github.com/kubernetes-sigs/prometheus-adapter>
- Il expose les métriques Prometheus en tant que **custom metrics API** dans Kubernetes
- Cela permet au **HPA** (Horizontal Pod Autoscaler) de scaler des pods sur la base de métriques Prometheus (ex: requêtes/s)

**Livrable**: rédigez un paragraphe de synthèse (5 lignes) pour chacun, expliquant son rôle et un cas d'usage concret.


### 2.3 — Approches de configuration: Jsonnet vs CRDs

Comparez les deux approches pour configurer le monitoring sur Kubernetes:

| Critère               | Jsonnet (kube-prometheus) | CRDs (Opérateur Prometheus) |
| --------------------- | ------------------------- | --------------------------- |
| Principe              |                           |                             |
| Avantages             |                           |                             |
| Inconvénients         |                           |                             |
| Exemple d'utilisation |                           |                             |
| Outillage nécessaire  |                           |                             |

**Livrable**: tableau comparatif rempli avec un exemple concret pour chaque approche.

Familiarisez-vous avec les ressources Custom Resource Definitions suivantes. Pour chacune, indiquez en une phrase son rôle:

| CRD                    | Rôle |
| ---------------------- | ---- |
| **ServiceMonitor**     |      |
| **PodMonitor**         |      |
| **PrometheusRule**     |      |
| **Alertmanager**       |      |
| **AlertmanagerConfig** |      |
| **Probe**              |      |
| **ScrapeConfig**       |      |


### 2.5 — Déploiement avec Helmfile

Déployez la stack complète sur votre cluster Kubernetes en utilisant **Helmfile**.

**Structure attendue**:

```
k8s/
  helmfile.yaml
  values/
    kube-prometheus-stack.yaml
    traefik.yaml
  manifests/
    training-app.yaml
    servicemonitor-traefik.yaml
    prometheusrule-app.yaml
```

**helmfile.yaml**:

```yaml
repositories:
  - name: prometheus-community
    url: https://prometheus-community.github.io/helm-charts
  - name: traefik
    url: https://traefik.github.io/charts

releases:
  - name: traefik
    namespace: traefik
    createNamespace: true
    chart: traefik/traefik
    version: 34.x.x # adapter à la dernière version stable
    values:
      - values/traefik.yaml
  - name: kube-prometheus-stack
    namespace: monitoring
    createNamespace: true
    chart: prometheus-community/kube-prometheus-stack
    version: 72.x.x # adapter à la dernière version stable
    values:
      - values/kube-prometheus-stack.yaml
```

**Tâches**:

1. Complétez le fichier `values/traefik.yaml` pour activer:
    - Les métriques Prometheus (`metrics.prometheus.enabled`)
    - L'access log au format JSON
    - L'IngressRoute pour le dashboard
2. Complétez le fichier `values/kube-prometheus-stack.yaml` pour:
    - Configurer la rétention Prometheus à 7 jours
    - Activer le stockage persistant (PVC de 10Gi)
    - Configurer Alertmanager (receiver email ou webhook de test)
    - Désactiver les composants inutiles pour le lab (ex: etcd, kubeScheduler, kubeProxy si non accessible)
3. Déployez avec:

    ```bash
    helmfile sync
    ```


### 2.6 — Déployer l'application et son monitoring

**Déployez training-app** via un manifeste Kubernetes (`manifests/training-app.yaml`):

- Deployment (3 replicas)
- Service (ClusterIP, port 80)
- IngressRoute Traefik (host: `app.k8s.localhost`)

**Créez un ServiceMonitor** (`manifests/servicemonitor-traefik.yaml`) pour que l'opérateur Prometheus scrape automatiquement les métriques Traefik:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: traefik
  namespace: traefik
  labels:
    release: kube-prometheus-stack # label requis par l'opérateur
spec:
  endpoints:
    - port: metrics
      interval: 15s
  namespaceSelector:
    matchNames:
      - traefik
  selector:
    matchLabels:
      app.kubernetes.io/name: traefik
```

**Créez une PrometheusRule** (`manifests/prometheusrule-app.yaml`) reprenant les alertes définies en 1.6, adaptées au contexte Kubernetes.

**Livrable**: les manifestes YAML déployés et fonctionnels.


### 2.7 — Validation et dashboards

1. Accédez à Grafana (port-forward ou IngressRoute) et vérifiez que les dashboards préconfigurés sont présents
2. Importez le dashboard créé en 1.7 (ou adaptez-le aux labels Kubernetes)
3. Générez du trafic vers `app.k8s.localhost` et vérifiez que:
    - Les métriques Traefik apparaissent dans Prometheus
    - Les alertes se déclenchent correctement
    - Le dashboard affiche les données en temps réel


## Bonus


### B.1 — Enrichissement des access logs avec GeoIP

`[option]` configurez le middleware GeoIP de Traefik (via un plugin ou un service externe) pour enrichir les logs avec le pays d'origine des requêtes.
Créez un panel Grafana de type **Geomap** affichant la répartition géographique des clients.


### B.2 — Autoscaling sur métriques custom

`[option]` Déployez le **prometheus-adapter** et configurez un HPA sur le Deployment `training-app` qui scale automatiquement entre 2 et 10 replicas en fonction du taux de requêtes/s par pod.


### B.3 — Ajout de Loki pour l'analyse des logs

`[option]` Ajoutez **Loki** au Helmfile et configurez Alloy/Promtail pour collecter les access logs Traefik. Créez un dashboard Grafana combinant métriques Prometheus et logs Loki pour une vue unifiée.


<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=fr,en : -->
