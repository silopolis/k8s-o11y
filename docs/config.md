# Mise en situation Orchestration et observabilité


## Partie 1 — Stack Docker Compose

**Architecture cible:**

![Architecture Docker Compose — Fédération Prometheus](https://hedgedoc.dawan.fr/uploads/1b55b37a-849a-4684-9adb-c17fe4ca0060.svg)


### 1.1 — Étude comparative des architectures de scaling Prometheus


#### En bref

- Modèles diffèrent fortement en terme :
  - de complexité,
  - de modèle de données,
  - de support multi-entités,
  - de haute disponibilité,
  - de besoins en stockage objet.
- Pour deux DCs avec un Prometheus central la fédération reste la solution la plus simple si les besoins sont modestes en volume, rétention et multi-entité.
- Thanos apporte :
  - la rétention à long terme,
  - la haute disponibilité inter-DC
  - une vue globale consolidée avec stockage objet
- Cortex & Mimir ciblent plutôt des plateformes "Metrics-as-a-Service", multi-clients, massivement multi-tenants et très fortement scalables, au prix d'une complexité d'exploitation bien plus élevée.


#### Contexte et problématique

- Deux DCs (`DC01` & `DC02`) hébergeant les services d'infrastructure, métiers et les charges de travail de formation
- Besoins de supervision locaux et une vue consolidée (vues globales, tableaux de bord et/ou alerting de haut niveau)
- Prometheus central "Master"
- Points de comparaison :
  - Scalabilité horizontale et gestion de la cardinalité.
  - Résilience inter‑datacenters et fonctionnement en cas de partition réseau.
  - Rétention à long terme et coûts de stockage.
  - Multi‑tenant (par client, promo, environnement, etc.).
  - Complexité d’exploitation et courbe d’apprentissage.


#### Fédération Prometheus


##### Principe et architecture

- Serveurs **Prometheus locaux** (*leaf nodes*) :
  - Dans chaque DC,
  - Chacun scrape ses cibles dans un périmètre donné (datacenter, cluster, zone fonctionnelle).
  - Stockent *toutes les séries détaillées* (instance‑level) avec une *rétention limitée*.
- Un ou plusieurs **Prometheus "globaux"** *scrapent les serveurs locaux* via la terminaison **`/federate`** pour **agréger des métriques sélectionnées**.
  - Stockent des agrégats (job‑level, service‑level) pour limiter la cardinalité et la charge.
- Le flux tiré (*pull*) :
  - le serveur de fédération collecte les métriques exposées par les instances locales via leur terminaison **`/federate`** en appliquant des *règles de sélection* **`match[]`**.
- La **topologie** peut être *hiérarchique*, avec plusieurs niveaux de Prometheus agrégateurs (edge → régional → global) pour les grandes organisations multi‑datacenters.


##### Avantages

- **Simplicité** conceptuelle et opérationnelle :
  - Technologie et configuration *100 % Prometheus*, sans composants externes.
- Adapté aux infrastructures avec *plusieurs datacenters* ou clusters où un seul Prometheus serait insuffisant en charge ou en latence réseau.
- Très bon pour :
  - *Vue globale* à partir de métriques déjà agrégées (SLO, SLA, KPIs de formation par DC, etc.).
  - *Isolation des pannes* : un Prometheus local en panne n’impacte pas les autres, la vue globale manquera seulement certaines métriques le temps de la panne.
- Ne nécessite *pas de stockage objet*, *ni de micro‑services supplémentaires*.


##### Limites et points de vigilance

- Pas de vrai *"single pane of glass"* sur toutes les **séries brutes** :
  - Vue globale limitée à ce qui est fédéré,
  - Bénéfique pour la scalabilité,
  - Contraignant pour certains diagnostics fins.
- **Réplication** complète des séries entre serveurs via fédération est déconseillée.
  Surcharge les Prometheus source et cible en CPU, mémoire et réseau.
- **Rétention** à long terme limitée par les capacités d’un seul nœud Prometheus pour chaque instance (locales et globale).
- **Haute disponibilité** nécessite des mécanismes complémentaires (Prometheus redondants par DC + mécanisme de bascule ou d’équilibrage).


##### Schéma type pour DC01 / DC02 / Master

- `DC01` : Prometheus DC01 scrape toutes les cibles locales (VM, pods, équipements, lab de formation, etc.).
- `DC02` : Prometheus DC02 avec le même rôle côté DC02.
- Master : configure :
  - un job **`/federate`** avec cibles DC01 et DC02, et
  - des **`match[]`** ne remontant que des *agrégats ou métriques clés*.
    Exemple : `job="*"` agrégé par service, client ou session de formation).

Ce modèle couvre bien un besoin de monitoring centralisé pour une entreprise de formation tant que la volumétrie reste raisonnable et que la rétention à long terme n’est pas critique.


#### Thanos


##### Principe et composants

Thanos est une couche complémentaire de Prometheus qui apporte :

- **Rétention longue durée** via *stockage objet* (S3, GCS, MinIO, etc.).
- **Haute disponibilité** et **déduplication** entre réplicas Prometheus.
- **Vue globale unifiée** de plusieurs Prometheus (multi‑cluster, multi‑DC) via un composant de requête central (*Querier* / *Query Frontend*).

Les composants principaux sont :

- **Sidecar**
  - Déployé à côté de chaque Prometheus,
  - *Expose l’API Store* de Thanos,
  - Peut uploader les blocs TSDB vers un stockage objet et permettre des requêtes distantes.
- **Querier**
  - Composant central
  - *Agrège les données* de multiples stores (sidecars, store‑gateways)
  - Fournit une *vue globale PromQL*.
- **Store Gateway**
  Sert les données historiques à partir du stockage objet.
- **Compactor**
  - Compacte, sous-échantillonne et déduplique les blocs dans le stockage objet,
  - Améliore les performances de requête et le coût de stockage.
- **Ruler**
  Évalue des règles d’alerte ou d’enregistrement sur les données globales.


##### Avantages

- **Rétention virtuellement illimitée**
  Les blocs Prometheus sont externalisés dans un stockage objet, permettant d’augmenter fortement la période de conservation et de réduire la pression sur les disques locaux.
- **Haute disponibilité native**
  - Déploiement de plusieurs réplicas Prometheus par DC avec chacun un *sidecar*,
  - Thanos Querier réalise la *déduplication* des séries entre réplicas et *comble les manques* de données en cas de panne d’un replica.
- **Vue globale transverse**
  - *Agrégation des données* venant de DC01, DC02 et d’autres clusters,
  - *API PromQL unique*, exploitable par Grafana et autres clients.
- *Intégration progressive*
  - Commencer par le mode Sidecar sans stockage objet, puis
  - Ajouter Store Gateway et Compactor pour l’historique long terme.


##### Limites et complexité

- Nécessite un **\*stockage objet** accessible par tous les datacenters*
  Implique des questions de *latence*, de *coûts* et de*sécurité\*.
- **Plusieurs services supplémentaires** à *déployer*, *monitorer* et *mettre à jour*
  Querier, Store Gateway, Compactor, Ruler, éventuellement Receivers.
  Augmente la complexité opérationnelle par rapport à la simple fédération.
- Le **dimensionnement et la configuration** (*topologie*, *flags*, *stratégies de downsampling et de rétention*) demandent des compétences spécifiques en observabilité à grande échelle.


##### Schéma type pour DC01 / DC02 / Master

- DC01 & DC02 :
  - Un ou deux Prometheus DC01 (pour HA) avec sidecar Thanos, stockant localement la rétention courte.
  - Les sidecars exposent l’API Store et uploadent les blocs vers le bucket objet commun.
- Couche centrale :
  - Thanos Querier (et éventuellement Query Frontend) déployé dans un des DC ou dans un troisième environnement.
  - Store Gateway et Compactor accèdent au même bucket objet.
  - Grafana et outils de training se connectent au Querier pour une vue unifiée multi‑DC.

Dans un contexte d’entreprise de formation, Thanos prend tout son sens si :

- Les labs génèrent beaucoup de métriques et l’historique sur plusieurs mois/années est utile (analyses de sessions, tendance des plateformes de formation).
- La haute disponibilité de la supervision est un objectif fort.


#### Cortex


##### Principe et architecture

Cortex est un système de *stockage de métriques* compatible Prometheus, *multi‑tenant* et *massivement scalable*, conçu pour la *haute disponibilité* et la *rétention à long terme*.
Il découpe la pipeline en micro‑services distincts, chacun pouvant être mis à l'échelle horizontalement :

- **Distributor**
  - Reçoit les métriques via *remote‑write*,
  - Applique *validation* / *relabeling*,
  - *Répartit les séries* sur les ingesters.
- **Ingester**
  *Stocke les échantillons* en mémoire puis en blocs sur un stockage longue durée (généralement objet).
  *Expose les données récentes* aux requêtes.
- **Querier & Query Frontend**
  *Exécutent les requêtes PromQL*, se connectent aux ingesters pour les données fraîches et au stockage pour l’historique.
- **Compactor**
  *Compacte et déduplique* les blocs dans le stockage objet pour améliorer performances et coûts.

Les Prometheus sources (dans chaque DC, cluster, tenant, etc.) envoient leurs données vers Cortex en mode **`remote‑write`**, éventuellement avec un *en‑tête de tenant* (par ex. `X-Scope-OrgID`).


##### Avantages

- **Multi‑tenant natif**
  - Isolation des métriques par tenant,
  - Idéal pour une plateforme partagée entre plusieurs clients ou équipes (ex. : chaque client formation ou chaque promo comme tenant distinct).
- **Scalabilité horizontale fine**
  Distributeurs, ingesters, queriers et frontends peuvent être *mis à l'échelle indépendamment* selon la charge (ingest vs lecture).
- **Haute disponibilité**
  Les échantillons sont répliqués sur plusieurs ingesters, et le système supporte la perte de nœuds individuels sans perte globale de données.
- **Rétention longue** durée similaire à Thanos via stockage objet.


##### Limites et complexité

- **Architecture plus complexe** que Thanos
  Plusieurs micro‑services à opérer, souvent déployés sur Kubernetes, avec un etcd ou un autre KV store pour les métadonnées selon le mode d’indexation historique.
- Nécessite un soin particulier sur :
  - le **sharding**,
  - la **replication factor**,
  - les **stratégies de compaction**,
  - la **gestion de la cardinalité**, et
  - la **gouvernance des tenants**.
- Généralement justifié pour des cas d’usage type :
  - *SaaS observability*,
  - Monitoring central de très nombreuses équipes ou clusters.


##### Schéma type pour DC01 / DC02 / Master

- DC01 et DC02 :
  - Chaque Prometheus local scrape ses cibles comme d’habitude.
  - Remote‑write vers l’endpoint Cortex exposé (par exemple via un load balancer Nginx ou Ingress), en taguant l’ID de tenant.[2]
- Couche centrale Cortex (pouvant être dans un DC ou répartie) :
  - Ensemble Distributor / Ingester / Querier / Query Frontend / Compactor connecté à un stockage objet partagé.[15][2]
  - Grafana se connecte directement à Cortex pour les requêtes.

Pour une entreprise de formation, ce modèle est pertinent si l’objectif est de faire de la supervision multi‑tenant « as a service » (par client, par université, par promo) à grande échelle, en acceptant une complexité d’exploitation proche d’une plateforme SaaS.


#### Grafana Mimir


##### Principe et architecture

Grafana Mimir est un **fork/évolution de Cortex** développé par *Grafana Labs*, offrant également un stockage de métriques Prometheus multi‑tenant, horizontalement scalable et à longue rétention.
Mimir reprend la plupart des concepts de Cortex (Distributor, Ingester, Querier, Query Frontend, Compactor, Store Gateway) avec *différentes optimisations et simplifications*.

Architecture typique :

- **Distributor**
  *Reçoit* les échantillons en `remote‑write`, les *valide* et les *shard* vers les ingesters.
- **Ingester**
  *Stocke* en mémoire, *découpe* en blocs, *entrepose* les métriques dans un stockage objet.
- **Compactor**
  *Compacte* et *déduplique* les blocs, maintient un *index de bucket par tenant*.
- **Store Gateway**
  *Sert les blocs historiques* depuis le stockage objet pour les requêtes.
- **Query Frontend** & **Querier**
  *Pipeline de requête* avec *splitting*, *caching* et *parallélisation* pour améliorer les performances.


##### Avantages

- **Multi‑tenant** et **hautement scalable**
  Similaire à Cortex, tout en bénéficiant des efforts d’*optimisation* récents de Grafana Labs (par exemple sur la pipeline de requêtage et la gestion des blocks).
- Intégration naturelle avec l’**écosystème Grafana** (Dashboards, Alerting, Tempo, Loki, etc.).
- Fonctionnalités avancées
  - Ingestion d’*échantillons out‑of‑order* (expérimental),
  - Options d’ingestion via WarpStream pour la scalabilité, etc.


##### Limites et complexité

- **Complexité opérationnelle** comparable à Cortex
  - nombreux services à déployer et surveiller,
  - dépendance à un stockage objet et à un KV store.
- Encore plus orienté vers les opérateurs de grandes plateformes d’observabilité (Grafana Cloud‑like) que vers de petits environnements multi‑DC.
- *Pas encore de downsampling intégré* (proposition encore en discussion)
  Peut impacter les coûts et performances pour des rétentions très longues avec fort volume.


##### Schéma type pour DC01 / DC02 / Master

- DC01 / DC02 :
  - Prometheus locaux avec `remote‑write` vers un *endpoint Mimir mutualisé*.
- Couche centrale Mimir :
  - Ensemble complet Distributor / Ingester / Store Gateway / Compactor / Querier / Query Frontend connectés au stockage objet.
  - Grafana (et éventuellement le Prometheus Master si conservé) se branche sur Mimir pour les queries.


#### Tableau comparatif synthétique

| Axe                       | Fédération Prometheus                                                                                                           | Thanos                                                                                                                          | Cortex                                                                                                                                         | Grafana Mimir                                                                                                         |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Modèle de données         | Prometheus local + agrégats fédérés                                                                                             | TSDB locale + blocs externalisés en objet                                                                                       | Stockage distribué multi‑tenant                                                                                                                | Stockage distribué multi‑tenant                                                                                       |
| Vue globale multi‑DC      | Oui, mais limitée aux séries fédérées                                                                                           | Oui, vue globale complète via Querier                                                                                           | Oui, via Cortex Querier                                                                                                                        | Oui, via Mimir Querier                                                                                                |
| Rétention long terme      | Limitée par chaque nœud Prometheus                                                                                              | Oui, via stockage objet + Compactor                                                                                             | Oui, via stockage objet + Compactor                                                                                                            | Oui, via stockage objet + Compactor                                                                                   |
| Haute disponibilité       | Par duplication de Prometheus + mécanismes externes                                                                             | Native (déduplication entre réplicas)                                                                                           | Native (réplication sur ingesters)                                                                                                             | Native (réplication sur ingesters)                                                                                    |
| Déduplication             | Aucune déduplication automatique entre réplicas, il faut éviter de pousser plusieurs fois la même série vers le même Prometheus | Déduplication au niveau du Querier sur un label de réplica (`--query.replica-label`), avec algorithmes `penalty`/`chain`.[1][2] | Le Querier déduplique les échantillons dupliqués dus au facteur de réplication des ingesters.[3]                                               | Déduplication HA intégrée : le distributor / HA tracker déduplique les paires de Prometheus en réplication.[4][5]     |
| Multi‑tenant              | Non (doit être géré par labels)                                                                                                 | Non natif, possible via labels et conventions                                                                                   | Oui, natif par tenant ID                                                                                                                       | Oui, natif par tenant ID                                                                                              |
| Complexité de déploiement | Faible : quelques Prometheus et configuration de fédération uniquement                                                          | Moyenne : ajout de sidecars, Querier, Store Gateway, Compactor, Ruler + stockage objet                                          | Élevée : plusieurs micro‑services (Distributor, Ingester, Querier, Query Frontend, Compactor, Store‑Gateway) + KV store + stockage objet[3][6] | Élevée : architecture similaire à Cortex avec zone‑aware replication, nombreux composants et stockage objet.[7][4][5] |
| Complexité d’exploitation | Faible                                                                                                                          | Moyenne                                                                                                                         | Élevée                                                                                                                                         | Élevée                                                                                                                |
| Besoin de stockage objet  | Non                                                                                                                             | Oui (pour historique)                                                                                                           | Oui                                                                                                                                            | Oui                                                                                                                   |
| Cas d’usage typique       | Quelques DC, besoin de vues agrégées, complexité minimale                                                                       | Multi‑DC/cluster avec HA + historique long terme                                                                                | Plateforme métriques multi‑tenant, grande échelle                                                                                              | Plateforme métriques multi‑tenant optimisée, intégrée Grafana                                                         |

Les informations du tableau proviennent de la documentation officielle Prometheus et Thanos, ainsi que de guides récents sur Thanos, Cortex et Grafana Mimir.


#### Recommandations pour une entreprise de formation avec deux DC


##### Quand privilégier la fédération Prometheus

La fédération est le meilleur point de départ si :

- **Volume de métriques modéré**
  Quelques centaines/milliers de cibles, rétention locale de quelques semaines à quelques mois.
- Objectif principal est d’avoir une **vue globale de haut niveau**
  Par plateforme de formation, par DC, par client, plutôt qu’une analyse détaillée cross‑DC sur toutes les séries brutes.
- Équipe Ops/DevOps limitée en *effectif* ou en *expertise* sur les plateformes distribuées.

Implémentation suggérée :

- **Un Prometheus par DC**
  - Éventuellement un second pour HA,
  - Synchronisation via enregistrements de cibles ou service discovery communs.
- **Un Prometheus central de fédération**
  - Fédère *uniquement les agrégats pertinents* (métriques `sum by (job, dc, customer, training_id)` par exemple).
  - Héberge les *règles d’alerting globales* et les *tableaux de bord transverses*.


##### Quand envisager Thanos

Thanos devient intéressant si un ou plusieurs de ces critères sont vrais :

- Besoin de **rétention long terme** (plusieurs mois/années) pour les métriques des labs, des plateformes LMS, ou pour des *analyses pédagogiques à long terme*.
- Exigences de **haute disponibilité** fortes, avec tolérance à la perte d’un DC ou d’un Prometheus *sans perte significative d’observabilité*.
- **Volumétrie croissante** (multiplication des environnements de formation, labs dynamiques Kubernetes, etc.).

Implémentation suggérée :

- Garder l’architecture avec un Prometheus par DC, mais *ajouter un sidecar* Thanos.
- Déployer un *stockage objet mutualisé* (par exemple MinIO multi‑site) accessible depuis DC01 et DC02.
- Déployer Thanos Querier, Store Gateway, Compactor et éventuellement Ruler dans le DC le plus fiable.
- Optionnel : conserver un Prometheus Master fédéré pour certaines vues spécifiques, mais déporter la majorité des dashboards sur Thanos Querier.


##### Quand privilégier Cortex ou Mimir

Cortex ou Mimir se justifient surtout dans des scénarios où l’entreprise de formation :

- Devient un *fournisseur de plateforme* d’observabilité pour de multiples clients, universités ou partenaires, avec un *modèle multi‑tenant explicite*.
- Souhaite centraliser la collecte de métriques de *dizaines/centaines de clusters ou environnements* de labs, avec une *croissance rapide de la cardinalité*.
- Dispose d’une *équipe SRE/plateforme* capable d’opérer une *stack micro‑services complexe* et un *cluster Kubernetes robuste*.

Entre Cortex et Mimir :

- Cortex offre un modèle éprouvé et neutre, largement utilisé pour des déploiements enterprise et dans plusieurs clouds.
- Mimir, étroitement couplé à Grafana, propose des optimisations et une intégration plus poussée à l’écosystème Grafana, au prix d’un alignement plus fort avec ce vendor.

Pour un simple besoin de deux datacenters avec un Master, ces solutions risquent d’être surdimensionnées et coûteuses à opérer, sauf si la stratégie d’entreprise prévoit clairement une montée en charge multi‑tenant de type SaaS.

Voici une version enrichie du tableau comparatif avec les deux nouveaux axes demandés.


#### Conclusion

Pour une entreprise de formation disposant de deux datacenters et d’un Prometheus central, la hiérarchie par fédération Prometheus représente généralement l’architecture la plus simple et suffisante, tant que le volume de métriques et les besoins de rétention restent raisonnables.
Thanos constitue une évolution naturelle lorsque les besoins en rétention longue durée, haute disponibilité et vue multi‑DC détaillée s’intensifient.

Cortex et Grafana Mimir sont, eux, adaptés aux opérateurs de plateformes d’observabilité multi‑tenant à très grande échelle et ne se justifient vraiment que si l’entreprise vise ce type de modèle ou si la volumétrie et la diversité des environnements de formation explosent.

- Pour un contexte avec seulement deux datacenters (DC01, DC02) et un Prometheus central, la **fédération** reste la solution la plus adaptée, car elle est simple à comprendre, à déployer et à maintenir.
- Elle permet d’avoir une vue globale sur les métriques clés via le Prometheus Master, tout en gardant la collecte détaillée et l’isolation des pannes au niveau de chaque DC.
- Thanos ajoute rétention long terme, vue globale complète et déduplication entre réplicas, mais au prix d’un stockage objet partagé et de plusieurs services supplémentaires à opérer, ce qui est souvent surdimensionné pour deux DC de formation.
- Cortex et Mimir ciblent des plateformes multi‑tenant massivement scalables, avec une architecture micro‑services nettement plus complexe, difficile à justifier sans besoin SaaS ou multi‑client à grande échelle.
- Recommandation : partir sur une fédération Prometheus hiérarchique (Prometheus DC01, Prometheus DC02, Prometheus Master) et ne considérer Thanos qu’en seconde étape si la volumétrie et la rétention long terme deviennent réellement critiques.


### 1.2 — Fédération Prometheus multi-datacenter


#### Configuration de la fédération


##### Ajout d'étiquettes externes (`external_labels`) aux métriques de chaque DC afin de les distinguer

1. Dupliquer le fichier de configuration partagé des serveurs Prometheus fédérés
2. Section `global` :

    ```yaml
    global:
      external_labels:
      datacenter: dc01
    ```


##### Configuration des cibles de collecte sur le serveur central

```yaml
scrape_configs:
  - job_name: "federate"
    honor_labels: true
    metrics_path: "/federate"
    params:
      #scrape_native_histograms: true`
      "match[]":
        - '{__name__=~".+"}'
    static_configs:
      - targets:
          - "dc01_prom:9090"
          - "dc02_prom:9090"
```


#### Vérifications


##### État des cibles pour les serveurs fédérés

```bash
curl -s 'http://fed.prom.localhost/api/v1/targets' \
  | jq '.data.activeTargets[] | select(.labels.job=="federate") | {target: .labels.instance, health: .health}'
```

Retourne :

```json
{
  "target": "dc01_prom:9090",
  "health": "up"
}
{
  "target": "dc02_prom:9090",
  "health": "up"
}
```


##### Présence des étiquettes externes

Toutes les métriques collectées depuis les serveurs fédérés comportent désormais une étiquette `datacenter`.

Exemple de vérifications :

- Consulter ou interroger n'importe quelle métrique (par exemple `up`), et vérifier la présence de l'étiquette `datacenter` :

  ```bash
  curl -s 'http://fed.prom.localhost/api/v1/query?query=up' | jq '.data.result[].metric.datacenter'
  ```

  Retourne :

  ```txt
  null
  null
  null
  "dc01"
  "dc01"
  ...
  "dc01"
  "dc02"
  ...
  "dc02"
  "dc01"
  "dc01"
  ```

  ```bash
  curl 'http://fed.prom.localhost/api/v1/query?query=up' | jq '.data.result[] | {instance: .metric.instance, datacenter: .metric.datacenter}'
  ```

  Retourne :

  ```json
  {
    "instance": "localhost:9090",
    "datacenter": null
  }
  ...
  {
    "instance": "cadvisor:8080",
    "datacenter": "dc01"
  }
  ...
  {
    "instance": "bbb.dawan.fr:22",
    "datacenter": "dc02"
  }
  ...
  ```

- Comptage du nombre de valeurs métrique par datacenter pour une métrique (ici `up`) :

  ```bash
  curl -s 'http://fed.prom.localhost/api/v1/query?query=count%20by%20(datacenter)%20(up)' \
    | jq '.data.result[] | {datacenter: .metric.datacenter, value: .value[1]}'
  ```

  Retourne :

  ```json
  {
    "datacenter": null,
    "value": "3"
  }
  {
    "datacenter": "dc01",
    "value": "19"
  }
  {
    "datacenter": "dc02",
    "value": "19"
  }
  ```

- Taux d'échantillonnage par datacenter :

  ```bash
  curl -s -X POST 'http://fed.prom.localhost/api/v1/query' \
    --data-urlencode 'query=rate(prometheus_tsdb_head_samples_appended_total{datacenter=~".+"}[5m])' \
    | jq '.data.result[]
      | select(.metric.type == "float")
      | {datacenter: .metric.datacenter, rate: .value[1]}'
  ```

  Retourne :

  ```json
  {
    "datacenter": "dc01",
    "rate": "1743.1549295774646"
  }
  {
    "datacenter": "dc02",
    "rate": "1733.3846153846155"
  }
  ```


### 1.3 — Scénarios de test de résilience


##### Règles d'alerte


###### GUI

- <http://fed.prom.localhost/rules>
- **Status** > **Rules health**
- Toutes règles `OK`


###### API

- Vérifier l'état général des règles

  ```bash
  curl -s 'http://fed.prom.localhost/api/v1/status/rules' | jq '.status'
  ```

  Retourne :

  ```json
  "success"
  ```

- Vérifier le nombre de règles

  ```bash
  curl -s 'http://fed.prom.localhost/api/v1/rules' | \
    jq '.data.groups[]
      | {name: .name, file: .file, rules_count: (.rules | length)}'
  ```

  Retourne :

  ```json
  {
    "name": "MONITORING",
    "file": "/etc/prometheus/rules/common/entreprise.yml",
    "rules_count": 4
  }
  ```

- Liste des règles et de leur état

  ```bash
  curl -s 'http://fed.prom.localhost/api/v1/rules' | \
    jq '.data.groups[]
      | {group: .name, rules: [.rules[] | {name: .name, health: .health, lastError: .lastError}]}'
  ```

  Retourne :

  ```json
  {
    "group": "MONITORING",
    "rules": [
      {
        "name": "CRITtargetDown",
        "health": "ok",
        "lastError": null
      },
      {
        "name": "WARNfilesystemAvailableSpace25",
        "health": "ok",
        "lastError": null
      },
      {
        "name": "CRITfilesystemAvailableSpace10",
        "health": "ok",
        "lastError": null
      },
      {
        "name": "CRITcertExpiration5d",
        "health": "ok",
        "lastError": null
      }
    ]
  }
  ```

- Liste des règles en erreur

  ```bash
  curl -s 'http://fed.prom.localhost/api/v1/rules' | \
    jq '.data.groups[].rules[]
      | select(.health != "ok")
      | {name: .name, health: .health, error: .lastError}'
  ```


##### Scénario A — Perte d'un datacenter

Pour tester le fonctionnement des alertes, nous arrêtons le serveur `dc01_prom` :

```bash
$ docker-compose -f federated-compose.yml stop dc01_prom
[+] stop 1/1
 ✔ Container dc01_prom Stopped
```


###### GUI

- <http://fed.prom.localhost/alerts>


###### API

- Nombre d'alertes par état

  ```bash
  curl -s 'http://fed.prom.localhost/api/v1/alerts' | jq '.data.alerts | group_by(.state) | map({state: .[0].state, count: length})'
  ```

  Retourne :

  ```json
  [
    {
      "state": "firing",
      "count": 1
    }
  ]
  ```

- Liste des alertes actives

  ```bash
  curl -s 'http://fed.prom.localhost/api/v1/alerts' | \
    jq '.data.alerts[]
      | {alert: .labels.alertname, state: .state, instance: .labels.instance, severity: .labels.severity, activeAt: .activeAt}'
  ```

  Retourne :

  ```json
  {
    "alert": "CRITtargetDown",
    "state": "firing",
    "instance": "dc01_prom:9090",
    "severity": "critical",
    "activeAt": "2026-03-09T20:35:06.487977347Z"
  }
  ```

  :::note
  L'alerte disparait et la liste se vide lorsque le serveur `dc01_prom` est redémarré.
  :::

- Vérification que le serveur de fédération collecte toujours les métriques des autres cibles :

  ```bash
  curl -s 'http://fed.prom.localhost/api/v1/query?query=up\{datacenter="dc02"\}' | jq '.data.result[] | {instance: .metric.instance, status: .value[1]}'
  {
    "instance": "cadvisor:8080",
    "status": "1"
  }
  {
    "instance": "localhost:9090",
    "status": "1"
  }
  {
    "instance": "node_exporter:9100",
    "status": "1"
  }
  {
    "instance": "process_exporter:9256",
    "status": "1"
  }
  {
    "instance": "traefik:8080",
    "status": "1"
  }
  ...
  ```


##### Scénario B — Perte du Master

- Arrêt du serveur de fédération

  ```bash
  $ docker-compose -f federated-compose.yml stop fed_prom
  [+] stop 1/1
  ✔ Container fed_prom Stopped
  ```

- Vérification de l'état des serveurs fédérés :

  ```bash
  curl -s 'http://dc01.prom.localhost/api/v1/query?query=up\{instance="localhost:9090",job="prometheus"\}' | jq '.data.result[0].value[1]'
  curl -s 'http://dc02.prom.localhost/api/v1/query?query=up\{instance="localhost:9090",job="prometheus"\}' | jq '.data.result[0].value[1]'
  ```

  Les deux commandes doivent retourner `"1"`.

- Redémarrage du serveur de fédération :

  ```bash
  $ docker-compose -f federated-compose.yml up fed_postgres -d
  [+] up 2/2
  ✔ Volume federated_fed_postgres_data  0.0s
  ✔ Container  Started
  ```

  Attendre quelques secondes que le premier cycle de collecte ait lieu.

- Vérification de la santé des cibles

  ```bash
  curl -s 'http://fed.prom.localhost/api/v1/targets' | jq '.data.activeTargets[] | select(.labels.job=="federate") | {target: .labels.instance, health: .health}'
  ```

  Retourne :

  ```json
  {
    "target": "dc01_prom:9090",
    "health": "up"
  }
  {
    "target": "dc02_prom:9090",
    "health": "up"
  }
  ```

Les métriques ne sont pas rattrapées, ce qui apparait de façon flagrante dans Grafana avec une interruption des graphiques pendant toute la durée d'indisponibilité du serveur de fédération.
Les données n'ayant pu être collectées en temps voulu sont définitivement perdues.


### 1.4 — Bilan et limites de la fédération native


#### Bilan global

- La fédération n’ajoute **aucun mécanisme HA ou de failover propre**
- Elle fonctionne très bien pour agréger des **agrégats à faible cardinalité** depuis plusieurs clusters,
- Le Prometheus global reste soumis aux mêmes limites CPU/RAM/disque qu’un Prometheus classique.
- Il n’existe **ni déduplication globale native**, **ni orchestration de bascule entre instances**
  Tout doit être géré par la conception des *labels*, des *règles* et de l’infrastructure autour.


#### HA inter‑cluster (Master indisponible)

- Si le Prometheus Master tombe, **les Prometheus fédérés continuent à scraper et à évaluer leurs propres alertes locales**, car ils sont totalement indépendants.
- **Toutes les alertes et règles définies uniquement sur le Master ne sont plus évaluées** tant qu’il est indisponible (SLO globaux multi‑DC, alertes agrégées, etc.).
- La fédération ne fournit pas de HA pour le Master : pour la tolérance aux pannes, il faut **déployer plusieurs Masters** (réplicas) et **gérer la redondance au niveau de l’Alertmanager, du load balancer ou des receivers**.


#### Failover régional

- La fédération native **ne propose aucun mécanisme de basculement automatique** entre régions ou datacenters
- La bascule se fait par des **mécanismes externes** :
  - DNS/load balancer qui redirige vers un autre Prometheus,
  - Règles d’Alertmanager avec plusieurs routes, ou
  - Duplication de jobs de scrape.
- Côté fédération, un deuxième Prometheus global peut scraper les mêmes Prometheus fédérés, mais ce n'est pas un failover régional natif.


#### Déduplication globale

- En fédération, **le Master voit chaque série fédérée comme une série normale**.
  S’il existe deux sources pour la même métrique (ex. même exporter scrapé par DC01 et DC02), il verra deux séries distinctes, différenciées par leurs labels (`dc`, `cluster`, `prometheus`, etc.).
- Il n’y a **pas de déduplication globale automatique**.
  Si deux séries ont exactement les mêmes labels (donc « même identité » pour Prometheus), on obtient des **erreurs** de type *out‑of‑order* / *different value but same timestamp*, ou des *doublons* qui **biaisent les agrégations**.
- La **gestion des doublons** repose sur :
  - La **conception des labels et `external_labels`** pour distinguer clairement chaque source (cluster, dc, prometheus_replica, etc.).
  - Le fait :
    - de **ne pas fédérer la même ressource depuis plusieurs Prometheus** (par design), ou
    - d’écrire des règles d’agrégation explicites pour sommer/moyenner selon les labels pertinents.


#### Scalabilité (nombre de séries fédérées)

- La documentation officielle indique que la fédération hiérarchique permet de monter à des environnements avec **dizaines de datacenters et millions de nœuds**, à condition que les Prometheus globaux ne collectent que des *séries déjà agrégées* (job‑level, service‑level).
- Malgré cela, **le Prometheus Master reste un TSDB mono‑nœud** : ses limites sont donc les mêmes qu’un Prometheus classique (cardinalité maximale, mémoire, CPU, temps de requête), la fédération ne fait qu’aider à répartir la collecte, pas à dépasser ces limites structurelles.
- Les **bonnes pratiques** recommandent de :
  - **Fédérer uniquement des agrégats** (SLO, métriques par service/cluster)
  - Ne **jamais fédérer les séries brutes à haute cardinalité** (pod‑level, request‑level).
  - **Surveiller le nombre de séries fédérées, la mémoire et la durée de scrape** du job `federate` pour détecter quand le Master approche de ses limites,
  - Restreindre les `match[]` ou introduire un niveau supplémentaire dans la hiérarchie lorsque les limites d'un noeud de fédération sont atteintes.
- Au‑delà d’un certain point (fédérations nombreuses, cardinalité croissante, besoin d’historique long terme), les retours d’expérience montrent que l’on migre généralement vers **Thanos / Cortex / Mimir**, précisément parce que la fédération ne résout pas les limites de scalabilité d’un nœud unique.


### 1.5 — Application observable avec Traefik

Traefik génère automatiquement des métriques pour tous les *services* et *routers* configurés.
Les métriques suivantes sont collectée, avec les *étiquettes* `service` ou `router` :

- `traefik_router_requests_total` : nombre total de requêtes par `router`
- `traefik_router_request_duration_seconds_*` : durée de la requête (`bucket`/`sum`/`count`)
- `traefik_service_requests_total` : nombre total de requêtes par service (load balancer)
- `traefik_service_request_duration_seconds_*` : durée de requête au niveau service
- `traefik_entrypoint_requests_total` : nombre de requêtes par point d'entrée

Pour les besoins de la mise en situation, une application minimale a été ajoutée à l'environnement avec trois instances déployées derrière un service Traefik :

```bash
$ docker-compose up training-app -d
[+] up 3/3
 ✔ Container tools-training-app-3 0.9s
 ✔ Container tools-training-app-1 0.6s
 ✔ Container tools-training-app-2 Started
```

- Lister les métriques générées par Traefik pour l'application `training-app` :

  ```bash
  docker exec dc01_prom wget -qO- http://traefik:8080/metrics | grep training
  ```

  Retourne :

  ```txt
  traefik_service_request_duration_seconds_bucket{code="200",method="GET",protocol="http",service="training-app-tools@docker",le="0.1"} 10
  traefik_service_request_duration_seconds_bucket{code="200",method="GET",protocol="http",service="training-app-tools@docker",le="0.3"} 10
  traefik_service_request_duration_seconds_bucket{code="200",method="GET",protocol="http",service="training-app-tools@docker",le="1.2"} 10
  traefik_service_request_duration_seconds_bucket{code="200",method="GET",protocol="http",service="training-app-tools@docker",le="5"} 10
  traefik_service_request_duration_seconds_bucket{code="200",method="GET",protocol="http",service="training-app-tools@docker",le="+Inf"} 10
  traefik_service_request_duration_seconds_sum{code="200",method="GET",protocol="http",service="training-app-tools@docker"} 0.011317342999999999
  traefik_service_request_duration_seconds_count{code="200",method="GET",protocol="http",service="training-app-tools@docker"} 10
  traefik_service_requests_bytes_total{code="200",method="GET",protocol="http",service="training-app-tools@docker"} 0
  traefik_service_requests_total{code="200",method="GET",protocol="http",service="training-app-tools@docker"} 10
  traefik_service_responses_bytes_total{code="200",method="GET",protocol="http",service="training-app-tools@docker"} 6889
  ```

  Ou par le biais d'une requête PromQL :

  ```bash
  curl -s 'http://fed.prom.localhost/api/v1/query?query=\{__name__=~"traefik.*",service=~"training-app.*"\}' | \
    jq '.data.result[] | .metric.__name__' | sort -u
  ```

  Qui retourne :

  ```txt
  "traefik_service_request_duration_seconds_bucket"
  "traefik_service_request_duration_seconds_count"
  "traefik_service_request_duration_seconds_sum"
  "traefik_service_requests_bytes_total"
  "traefik_service_requests_total"
  "traefik_service_responses_bytes_total"
  ```

L'utilisation d'un générateur de traffic permet de faire apparaître des pics dans les graphiques des métriques du service dans Grafana.


### 1.6 — Recording rules et alertes pour l'application


#### Règles d'enregistrement

```yaml
---
# _rec_app.yml
groups:
  - name: "APP_RECORDING"
    rules:
      - record: "app:request_rate:by_service_code"
        expr: "sum by (service, code) (rate(traefik_service_request_duration_seconds_count[5m]))"

      - record: "app:latency_p50:by_service"
        expr: "histogram_quantile(0.50, sum by (service, le) (rate(traefik_service_request_duration_seconds_bucket[5m])))"

      - record: "app:latency_p90:by_service"
        expr: "histogram_quantile(0.90, sum by (service, le) (rate(traefik_service_request_duration_seconds_bucket[5m])))"

      - record: "app:latency_p99:by_service"
        expr: "histogram_quantile(0.99, sum by (service, le) (rate(traefik_service_request_duration_seconds_bucket[5m])))"

      - record: "app:error_rate:by_service"
        expr: 'sum by (service) (rate(traefik_service_request_duration_seconds_count{code=~"5.."}[5m])) / sum by (service) (rate(traefik_service_request_duration_seconds_count[5m]))'
```


##### Explication des règles d'enregistrement

1. **`app:request_rate:by_service_code`**
    - Expression :

      ```promql
      sum by (service, code) (
        rate(traefik_service_request_duration_seconds_count[5m])
      )
      ```

    - Décomposition :
      - `traefik_service_request_duration_seconds_count` : Compteur total de requêtes Traefik (métrique native)
      - `[5m]` : Fenêtre de temps glissante de 5 minutes
      - `rate(...)` : Calcule le *taux de changement par seconde sur la fenêtre* (requêtes/sec)
      - `sum by (service, code)` : Agrège et groupe par service et code HTTP
    - Résultat :

      Requêtes/seconde par service et code HTTP (ex: training-app@docker + 200)

1. **`app:latency_p50/p90/p99:by_service`**
    - Expression :

      ```promql
      histogram_quantile(0.50,
        sum by (service, le) (
          rate(traefik_service_request_duration_seconds_bucket[5m])
        )
      )
      ```

    - Décomposition :
      - `traefik_service_request_duration_seconds_bucket` : Buckets histogramme des latences
      - `rate(...[5m])` : Taux d'arrivée dans chaque bucket sur 5min
      - `sum by (service, le)` : Agrège par service et borne supérieure (le = less than or equal)
      - `histogram_quantile(0.50)` : Calcule le 50ème percentile (médiane) de la distribution
      - Versions :
        - `0.50` → Médiane (50% des requêtes plus rapides)
        - `0.90` → 90ème percentile (90% des requêtes plus rapides)
        - `0.99` → 99ème percentile (99% des requêtes plus rapides)
    - Résultat :

      Latence en secondes pour chaque percentile par service

1. **`app:error_rate:by_service`**
    - Expression :

      ```promql
      sum by (service) (
        rate(traefik_service_request_duration_seconds_count{code=~"5.."}[5m])
      )
      /
      sum by (service) (
        rate(traefik_service_request_duration_seconds_count[5m])
      )
      ```

    - Décomposition :
      - Numérateur (erreurs 5xx) :
        - `{code=~"5.."}` : Regex matche les codes 500-599 (erreurs serveur)
        - `rate[...](5m)` : Taux d'erreurs/seconde
        - `sum by (service)` : Total par service
      - Dénominateur (total requêtes) :
        - Toutes les requêtes sans filtre de code
      - Division :
        - Ratio erreurs 5xx / total requêtes (valeur entre 0 et 1)
        - Ex: 0.15 = 15% de taux d'erreur
    - Résultat :

      Pourcentage d'erreurs 5xx par service.


##### Avantage des Recording Rules

| Aspect        | Sans recording                    | Avec recording                   |
| ------------- | --------------------------------- | -------------------------------- |
| Calcul        | Recalculé à chaque requête        | Calculé une fois par évaluation  |
| Performance   | Lourd (histogramme = cher)        | Instantané                       |
| Réutilisation | Copier-coller la requête complexe | Référence simple                 |
| Alertes       | Risque d'erreur de syntaxe        | Utilise la métrique pré-calculée |


##### Test des règles d'enregistrement

- Vérification du chargement des règles :

  ```bash
  curl -s "http://fed.prom.localhost/api/v1/rules" | jq '.data.groups[] | select(.name | contains("APP"))'
  ```

  Renvoie :

  ```json
  {
    "name": "APP_RECORDING",
    "file": "/etc/prometheus/rules/common/_rec_app.yml",
    "rules": [
      {
        "name": "app:request_rate:by_service_code",
        "query": "sum by (service, code) (rate(traefik_service_request_duration_seconds_count[5m]))",
        "health": "ok",
        "evaluationTime": 0.000391579,
        "lastEvaluation": "2026-03-10T11:14:48.608563159Z",
        "type": "recording"
      },
      ...
    ],
    "interval": 15,
    "limit": 0,
    "evaluationTime": 0.003597515,
    "lastEvaluation": "2026-03-10T11:14:48.60854805Z"
  }
  {
    "name": "APP_ALERTS",
    "file": "/etc/prometheus/rules/common/app.yml",
    "rules": [
      {
        "state": "inactive",
        "name": "WARNAppHighErrorRate",
        "query": "app:error_rate:by_service > 0.05",
        "duration": 300,
        "keepFiringFor": 0,
        "labels": {
          "severity": "warning"
        },
        "annotations": {
          "description": "Le service {{ $labels.service }} présente un taux d'erreur 5xx de {{ $value | humanizePercentage }} pendant plus de 5 minutes.",
          "summary": "Taux d'erreur élevé (5xx > 5%) sur {{ $labels.service }}"
        },
        "alerts": [],
        "health": "ok",
        "evaluationTime": 0.0001208,
        "lastEvaluation": "2026-03-10T11:14:36.133190094Z",
        "type": "alerting"
      },
      ...
    ],
    "interval": 15,
    "limit": 0,
    "evaluationTime": 0.000667896,
    "lastEvaluation": "2026-03-10T11:14:36.133160982Z"
  }
  ```

- Vérification des métriques pré-calculées :
  Vérifier que les règles d'enregistrement produisent des données

  ```bash
  curl -s 'http://fed.prom.localhost/api/v1/query?query=app:request_rate:by_service_code' | jq
  ```

  Renvoie :

  ```json
  {
    "status": "success",
    "data": {
      "resultType": "vector",
      "result": [
        {
          "metric": {
            "__name__": "app:request_rate:by_service_code",
            "code": "200",
            "service": "dc01-prom-federated@docker"
          },
          "value": [
            1773151184.804,
            "0"
          ]
        },
        {
          "metric": {
            "__name__": "app:request_rate:by_service_code",
            "code": "200",
            "service": "dc02-prom-federated@docker"
          },
          "value": [
            1773151184.804,
            "0"
          ]
        },
        ...
    }
  }
  ```

  ```bash
  curl -s 'http://fed.prom.localhost/api/v1/query?query=app:latency_p99:by_service' | jq
  ```

  Renvoie :

  ```json
  {
    "status": "success",
    "data": {
      "resultType": "vector",
      "result": [
        {
          "metric": {
            "__name__": "app:latency_p99:by_service",
            "service": "fed-prom-federated@docker"
          },
          "value": [
            1773151778.158,
            "NaN"
          ]
        },
        {
          "metric": {
            "__name__": "app:latency_p99:by_service",
            "service": "wud@docker"
          },
          "value": [
            1773151778.158,
            "NaN"
          ]
        },
        ...
    }
  }
  ```

  ```bash
  curl -s 'http://fed.prom.localhost/api/v1/query?query=app:error_rate:by_service' | jq
  ```

  Renvoie :

  ```json
  {
    "status": "success",
    "data": {
      "resultType": "vector",
      "result": [
        {
          "metric": {
            "__name__": "app:error_rate:by_service",
            "service": "fed-grafana-federated@docker"
          },
          "value": [1773151977.358, "0"]
        }
      ]
    }
  }
  ```


##### Démonstration des enregistrements


###### Comparaison avec/sans règles d'enregistrement

- **Sans** recording rule (lent, à recalculer à chaque requête)

  ```promql
  histogram_quantile(0.99,
    sum by (service, le) (
      rate(traefik_service_request_duration_seconds_bucket[5m])
    )
  )
  ```

  ```bash
  $ time (
    i=0
    while [ $i -lt 100 ]; do
      curl -s -X POST 'http://fed.prom.localhost/api/v1/query' \
        --data-urlencode 'query=histogram_quantile(
            0.99,
            sum by (service, le) (
              rate(traefik_service_request_duration_seconds_bucket[5m])
            )
          )' > /dev/null
      i=$((i+1))
    done
  )

  real 1,25s
  user 0,47s
  sys  0,47s
  cpu  75%
  ```

- **Avec** recording rule (instantané, déjà pré-calculé)

  ```promql
  app:latency_p99:by_service
  ```

  ```bash
  $ time (for i in {1..100}; do
    curl -s -X POST 'http://fed.prom.localhost/api/v1/query' \
      --data-urlencode 'query=app:latency_p99:by_service' > /dev/null
  done)

  real 0,99s
  user 0,41s
  sys  0,46s
  cpu  87%
  ```

Sur une requête simple et un test dans lequel le temps de calcul de celle-ci n'est probablement pas l'essentiel, on constate déjà un gain de plus de 25% en utilisant une métrique pré-calculée.


###### Dashboard de requêtes optimisées

- Latence p99 pour tous les services (rapide)

  ```promql
  app:latency_p99:by_service
  ```

- Top 5 services par taux d'erreur
  - Type : Bar Gauge (horizontal)
  - Query : `topk(5, app:error_rate:by_service)`
  - Description : Affiche les 5 services avec le plus haut taux d'erreur `5xx`
  - Seuils visuels : Vert (0-5%) → Jaune (5-15%) → Rouge (>15%)
- Comparer p50 vs p90 vs p99 sur un même graphe
  - Type : Time Series (lignes)
  - Queries :
    app:latency_p50:by_service # Bleu, ligne fine
    app:latency_p90:by_service # Orange, ligne moyenne
    app:latency_p99:by_service # Rouge, ligne épaisse
  - Description : Superposition des 3 percentiles pré-calculés par service
  - Styles : Épaisseurs de ligne croissantes (P50=1, P90=2, P99=3)

    ```promql
    app:latency_p50:by_service{service="training-app@docker"}
    app:latency_p90:by_service{service="training-app@docker"}
    app:latency_p99:by_service{service="training-app@docker"}
    ```


#### Règles d'alerte

```yaml
---
# app.yml
groups:
  - name: "APP_ALERTS"
    rules:
      - alert: "WARNAppHighErrorRate"
        expr: "app:error_rate:by_service > 0.05"
        for: "5m"
        labels:
          severity: "warning"
        annotations:
          summary: "Taux d'erreur élevé (5xx > 5%) sur {{ $labels.service }}"
          description: "Le service {{ $labels.service }} présente un taux d'erreur 5xx de {{ $value | humanizePercentage }} pendant plus de 5 minutes."

      - alert: "CRITAppHighErrorRate"
        expr: "app:error_rate:by_service > 0.15"
        for: "2m"
        labels:
          severity: "critical"
        annotations:
          summary: "Taux d'erreur CRITIQUE (5xx > 15%) sur {{ $labels.service }}"
          description: "Le service {{ $labels.service }} présente un taux d'erreur 5xx critique de {{ $value | humanizePercentage }} pendant plus de 2 minutes."

      - alert: "WARNAppHighLatencyP99"
        expr: "app:latency_p99:by_service > 0.8"
        for: "5m"
        labels:
          severity: "warning"
        annotations:
          summary: "Latence P99 élevée (> 800ms) sur {{ $labels.service }}"
          description: "Le service {{ $labels.service }} présente une latence P99 de {{ $value | humanizeDuration }} pendant plus de 5 minutes."

      - alert: "CRITAppServiceDown"
        expr: 'up{job="traefik"} == 1 unless on (instance) (traefik_service_up{service="training-app@docker"} == 1)'
        for: "1m"
        labels:
          severity: "critical"
        annotations:
          summary: "Service training-app DOWN - absent des targets Traefik"
          description: "Le service training-app@docker n'est pas présent dans les targets Traefik depuis plus de 1 minute."
```


##### Explication des règles

Explication de l'expression pour la règle `CRITAppServiceDown` :

- Utilise l'opérateur **`unless`** pour *détecter l'absence du service* :

  ```promql
  up{job="traefik"} == 1
  unless on (instance)
  (traefik_service_up{service="training-app@docker"} == 1)
  ```

- Décomposition : 01. `up{job="traefik"} == 1`
   Sélectionne les *instances où le job Traefik répond* (scraping OK) 02. `traefik_service_up{service="training-app@docker"} == 1`
   Vérifie que le *service `training-app@docker` est présent dans les targets Traefik* 03. `unless on (instance)`
   *Opérateur d'exclusion* : retourne les éléments à gauche qui n'ont pas de correspondance à droite, en joignant sur le label instance

- Logique :
  - Si Traefik est UP (gauche) ET training-app est absent/down (pas de match droite) → L'alerte se déclenche
  - Si Traefik est UP ET training-app est UP (match droite) → Pas d'alerte
  - Si Traefik est DOWN (gauche vide) → Pas d'alerte (évite les faux positifs)
- Pourquoi cette approche ?
  - Évite de déclencher l'alerte si Traefik lui-même est down
  - Détecte spécifiquement quand un service disparaît du load balancer (plus exposé)
  - Plus fiable que de simplement checker up{job="training-app"} qui ne capture pas les problèmes de routing


##### Vérification des alertes


###### Vérification des alertes configurées

```bash

```


###### Simuler les alertes

- Générer des erreurs 5xx :
  - Envoyer 100 requêtes avec un taux d'erreur élevé

    ```bash
    for i in {1..100}; do
      curl -s -o /dev/null -w "%{http_code}" http://localhost/api/error &
    done
    ```

  - Ou utiliser un outil de load testing

    ```bash
    ab -n 1000 -c 10 http://localhost/api/fail
    ```

- Vérifier l'état des alertes :

Voir si les conditions d'alerte sont remplies

app:error_rate:by_service > 0.05

Voir les services en cours d'alerte

ALERTS{alertname=~"WARNAppHighErrorRate|CRITAppHighErrorRate"} 04. Démontrer l'intérêt avec un scénario
Scénario 1 : Latence élevée


# 1. Générer du trafic lent


while true; do curl -s <http://localhost/api/slow>; done


# 2. Observer dans Prometheus


# app:latency_p99:by_service devrait monter progressivement


# L'alerte WARNAppHighLatencyP99 se déclenchera après 5m


Scénario 2 : Taux d'erreur critique


# 1. Faire planter le service temporairement


docker stop training-app


# 2. L'alerte CRITAppServiceDown se déclenche après 1m


# 3. Redémarrer


docker start training-app
Scénario 3 : Stress test complet


# Script de test complet


# !/bin/bash


echo "=== Test de charge normal ==="
wrk -t4 -c100 -d30s <http://localhost/api/health>
echo "=== Test avec erreurs ==="
for i in {1..500}; do curl -s <http://localhost/api/error>; done
echo "=== Vérifier les métriques ==="
curl -s "<http://localhost:9090/api/v1/query?query=app:error_rate:by_service>" 05. Vérification dans l'interface Grafana
Créer un dashboard avec ces panels :
Panel 1 - Requêtes par code HTTP :
sum by (code) (app:request_rate:by_service_code)
Panel 2 - Latence percentiles :
app:latency_p50:by_service
app:latency_p90:by_service
app:latency_p99:by_service
Panel 3 - Heatmap des erreurs :
app:error_rate:by_service


## Adaptation à l'environnement Kubernetes


## 2.1 — Chart Helm kube-prometheus-stack


### Composants inclus

- Le chart installe les composants principaux de la pile de surveillance des métriques basée sur Prometheus, sur Kubernetes :
  - Prometheus Operator,
  - Prometheus,
  - Alertmanager,
  - Grafana,
  - des exporters, et
  - des règles/dashboards prédéfinis.
- Il embarque comme dépendances les charts :
  - `kube-state-metrics`,
  - `prometheus-node-exporter`, et `grafana/grafana`
- Les dépendances sont déployées automatiquement sauf si on les désactive via `kubeStateMetrics.enabled`, `nodeExporter.enabled` et `grafana.enabled`.
- Le chart crée également les *CRDs Prometheus Operator* suivantes (non supprimées à l’uninstall) :
  - `Alertmanager`,
  - `AlertmanagerConfig`,
  - `PodMonitor`,
  - `Probe`,
  - `PrometheusAgent`,
  - `Prometheus`,
  - `PrometheusRule`,
  - `ScrapeConfig`,
  - `ServiceMonitor`,
  - `ThanosRuler`.
- Le chart ne déploie pas certains composants du projet kube-prometheus comme le **Prometheus Adapter** ou le **blackbox exporter**, qu’il faut installer séparément si nécessaire.


### Values importantes


#### Rétention

- **Rétention Prometheus** : **`prometheus.prometheusSpec.retention`**
  Contrôle la *durée de conservation des métriques*.
  Paramètre critique pour la *taille disque* et la *durée d’historique disponible*.
  Par défaut 10 jours dans les valeurs résumées.
- **Rétention Alertmanager** : **`alertmanager.alertmanagerSpec.retention`**
  Définit la durée de *rétention des données d’Alertmanager* (par défaut `120h`).
  Impacte la *persistance de l’historique des notifications* (silences, état des alertes, etc.).


#### Resources

**`prometheus.prometheusSpec.resources`** et **`alertmanager.alertmanagerSpec.resources`** permettent de définir *requests/limits* CPU et mémoire, indispensables pour stabiliser la stack en production.


#### Stockage

- **Stockage Prometheus** : **`prometheus.prometheusSpec.storageSpec`**
  Permet de définir un `volumeClaimTemplate` avec `storageClassName`, `accessModes` et `resources.requests.storage` (ex. 50 Gi), ce qui conditionne la persistance des séries temporelles Prometheus.
- **Stockage Alertmanager** : **`alertmanager.alertmanagerSpec.storage`**
  Expose la même logique (bloc **`volumeClaimTemplate`**) pour stocker l’état d’Alertmanager dans un PVC plutôt qu’en `emptyDir`.


#### Configuration Alertmanager

Le bloc **`alertmanager.config`** fournit une configuration par défaut (global, `inhibit_rules`, `route`, `receivers`, `templates`), que l’on peut surcharger :

- soit en modifiant ce YAML,
- soit via `stringConfig`/`tplConfig`,
- soit en externalisant la config dans des **`AlertmanagerConfig`** sélectionnés via **`alertmanager.alertmanagerSpec.alertmanagerConfigSelector`**.


### Provisioning automatique des dashboards Grafana

- Le chart provisionne une collection de dashboards Grafana qui sont automatiquement chargés via des `ConfigMaps`.
- Les dashboards sont *rendus* sous **`templates/grafana/`**, mais *générés* en amont par des *scripts Jsonnet/mixins* dans **`hack/`**.
- Ces `ConfigMaps` de dashboards sont ensuite automatiquement importés par le chart Grafana dépendant, qui inclut un *sidecar* capable de charger des `datasources` et dashboards à partir de `ConfigMaps` dans le cluster.
- Autrement dit, lors de l’installation de `kube-prometheus-stack`, Helm applique des manifests `ConfigMap` contenant les JSON de dashboards, puis le sidecar Grafana surveille ces `ConfigMaps` (via *labels/annotations*) et les injecte dans Grafana sans intervention manuelle.


## 2.2 — Comprendre l’écosystème Prometheus sur Kubernetes


### L’Opérateur Prometheus

L’Opérateur Prometheus est un **contrôleur** Kubernetes qui *crée, configure et gère des clusters Prometheus, Alertmanager et ThanosRuler à partir de CRDs* comme `Prometheus`, `Alertmanager` et `ThanosRuler`.

Il *surveille* en continu ces **ressources "instance-based"** et *déploie* les **`StatefulSet`** correspondants avec le bon nombre de *réplicas*, *stockage persistant* et *configuration réseau*.

En parallèle, il *consomme* des **CRDs "config-based"** (`ServiceMonitor`, `PodMonitor`, `Probe`, `ScrapeConfig`, `PrometheusRule`, `AlertmanagerConfig`) via des *sélecteurs de labels/namespace* pour *générer* automatiquement la *configuration de scraping et de règles*.

Un cas d’usage concret :

- on déploie un `Prometheus` avec un `serviceMonitorSelector` large ;
- chaque équipe d’application crée son propre `ServiceMonitor` et ses `PrometheusRule` ;
- l’Opérateur découvre ces objets et reconfigure Prometheus sans redéploiement manuel ni modification de `prometheus.yml`.

Cela permet de :

- **déléguer la configuration de monitoring aux équipes applicatives**
- tout en gardant un Prometheus central opéré de façon déclarative par les équipes de support (DevOps, SRE, Admin)


### L’Adaptateur Prometheus

**Prometheus Adapter** est une implémentation des APIs Kubernetes Custom Metrics et External Metrics (`custom.metrics.k8s.io`, `external.metrics.k8s.io`) qui s’appuie sur Prometheus comme *fournisseur de métriques*.

Il interroge périodiquement Prometheus, transforme les noms/labels de métriques en ressources Kubernetes (pods, services, namespaces, etc.) et *expose* ces valeurs via les *endpoints Custom/External Metrics* pour que des consommateurs comme le *Horizontal Pod Autoscaler (HPA) v2* puissent s’en servir.

Concrètement, cela permet de *mettre à l'échelle les charges de travail* (`Deployment`) non plus seulement par rapport aux CPU/mémoire, mais en fonction des métriques issues de Prometheus telles que, par exemple, `http_requests_per_second`, la latence p95 ou la longueur d’une file de messages.
Par exemple, un HPA peut cibler à la fois `cpu` et un custom metric `http_requests_per_second` via le type `Pods`, l’adapter se chargeant de fournir ces métriques agrégées par pod à partir de Prometheus.
C’est particulièrement utile pour mettre en place des stratégies de **mise à l'échelle "business-driven"** (sur le trafic ou les *événements métier*) plutôt que seulement techniques.


## 2.3 — Jsonnet (kube-prometheus) vs CRDs (Prometheus Operator)


### Tableau comparatif des approches

| Critère               | Jsonnet (kube-prometheus)                                                                                                                                                                                                                                        | CRDs (Opérateur Prometheus)                                                                                                                                                                                                                                |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Principe              | Bibliothèque Jsonnet (`kube-prometheus`) qui *génère tous les manifests* Kubernetes (Prometheus, Alertmanager, Grafana, exporters, ServiceMonitors, PrometheusRules, etc.) à partir de fichiers **`.jsonnet`** versionnés, puis application via `kubectl apply`. | *API déclarative* 100 % Kubernetes : on crée/édite des **CRDs** (`Prometheus`, `Alertmanager`, `ServiceMonitor`, `PodMonitor`, `PrometheusRule`,…) et l’Opérateur reconcilie en continu l’état réel avec l’état désiré.                                    |
| Avantages             | Très puissant pour le **templating** *multi‑environnements*, permet d’assembler des *"monitoring mixins"* (dashboards + règles) et de tout piloter depuis *une seule couche Jsonnet/GitOps*.                                                                     | Intègre le monitoring dans le *workflow Kubernetes standard* : chaque équipe peut créer son `ServiceMonitor`/`PrometheusRule` sans modifier la stack centrale, bénéfices de *RBAC* et de la réflexion en objets Kubernetes.                                |
| Inconvénients         | Nécessite une *toolchain spécifique* (Jsonnet, `jsonnet-bundler`, `gojsontoyaml`, scripts `build.sh`) et une bonne maîtrise de Jsonnet ; *chaque modification requiert de régénérer* et ré-appliquer les manifests.                                              | La configuration est dispersée dans de *nombreux objets*, ce qui peut rendre la vue d’ensemble plus difficile ; il faut gérer soigneusement les `*Selector` pour ne pas scraper trop ou pas assez de cibles.                                               |
| Exemple d’utilisation | Un repo d’infra utilise `kube-prometheus` comme librairie Jsonnet : un `example.jsonnet` définit le namespace `monitoring`, les namespaces scrutés et les mixins activés, puis un script génère tous les manifests et les applique (GitOps ArgoCD/Flux).         | Une plateforme expose un Prometheus géré par l’Opérateur ; chaque équipe applicative ajoute un `ServiceMonitor` pour son `Service` et un `PrometheusRule` pour ses SLOs, automatiquement pris en compte par Prometheus sans retoucher l’instance centrale. |
| Outillage nécessaire  | Binaire `jsonnet`, `jsonnet-bundler (jb)`, éventuellement `gojsontoyaml`, plus `kubectl`/un outil GitOps pour appliquer les manifests générés.                                                                                                                   | `kubectl` (ou kustomize/Helm) pour créer les CRDs et objets, plus le chart `kube-prometheus-stack` ou l’Operator installé à part pour fournir le contrôleur et les CRDs.                                                                                   |


### Rôle des principales CRDs Prometheus Operator

| CRD                    | Rôle                                                                                                                                                                                                                  |
| ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **ServiceMonitor**     | Décrit *comment Prometheus doit scraper un ensemble dynamique de Services* (sélection par labels, ports, TLS, relabeling) afin de *découvrir et configurer automatiquement les endpoints* exposés par ces Services.   |
| **PodMonitor**         | Définit *comment Prometheus doit scraper un ensemble de Pods* directement (sélection par labels de Pod, ports, auth, relabeling), utile quand on ne veut pas ou ne peut pas passer par un Service.                    |
| **PrometheusRule**     | Regroupe des *règles d’alerte et d’enregistrement* que Prometheus ou ThanosRuler évaluent en continu, ce qui permet de définir des alertes et des métriques agrégées de façon déclarative.                            |
| **Alertmanager**       | *Spécifie l’instance ou le cluster Alertmanager* souhaité (réplicas, stockage, options réseau) ; pour chaque ressource, l’Opérateur déploie un `StatefulSet` Alertmanager correspondant.                              |
| **AlertmanagerConfig** | Porte des *sous-parties de configuration Alertmanager* (routes, receivers, règles d’inhibition) qui sont sélectionnées et fusionnées par l’Opérateur pour constituer la configuration finale d’un Alertmanager donné. |
| **Probe**              | Configure des *sondes de type blackbox* : quelles adresses/Ingress sont testées, par quel prober (souvent blackbox exporter) et comment publier les métriques de disponibilité à scraper par Prometheus.              |
| **ScrapeConfig**       | Permet de définir des *configurations de scraping avancées* (cibles externes au cluster, autres mécanismes de découverte) impossibles ou peu pratiques avec seulement `ServiceMonitor`/`PodMonitor`/`Probe`.          |


<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=fr,en : -->
