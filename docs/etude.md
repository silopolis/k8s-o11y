# Mise à l'échelle Prometheus en environnement multi-datacenter


## En bref

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


## Contexte et problématique

- Deux DCs (`DC01` & `DC02`) hébergeant les services d'infrastructure, métiers et les charges de travail de formation
- Besoins de supervision locaux et une vue consolidée (vues globales, tableaux de bord et/ou alerting de haut niveau)
- Prometheus central "Master"
- Points de comparaison :
  - Scalabilité horizontale et gestion de la cardinalité.
  - Résilience inter‑datacenters et fonctionnement en cas de partition réseau.
  - Rétention à long terme et coûts de stockage.
  - Multi‑tenant (par client, promo, environnement, etc.).
  - Complexité d’exploitation et courbe d’apprentissage.


## Fédération Prometheus


### Principe et architecture

- Serveurs **Prometheus locaux** (*leaf nodes*) :
  - Dans chaque DC,
  - Chacun scrape ses cibles dans un périmètre donné (datacenter, cluster, zone fonctionnelle).
  - Stockent *toutes les séries détaillées* (instance‑level) avec une *rétention limitée*.
- Un ou plusieurs **Prometheus "globaux"** *scrapent les serveurs locaux* via la terminaison **`/federate`** pour **agréger des métriques sélectionnées**.
  - Stockent des agrégats (job‑level, service‑level) pour limiter la cardinalité et la charge.
- Le flux tiré (*pull*) :
  - le serveur de fédération collecte les métriques exposées par les instances locales via leur terminaison **`/federate`** en appliquant des *règles de sélection* **`match[]`**.
- La **topologie** peut être *hiérarchique*, avec plusieurs niveaux de Prometheus agrégateurs (edge → régional → global) pour les grandes organisations multi‑datacenters.


### Avantages

- **Simplicité** conceptuelle et opérationnelle :
  - Technologie et configuration *100 % Prometheus*, sans composants externes.
- Adapté aux infrastructures avec *plusieurs datacenters* ou clusters où un seul Prometheus serait insuffisant en charge ou en latence réseau.
- Très bon pour :
  - *Vue globale* à partir de métriques déjà agrégées (SLO, SLA, KPIs de formation par DC, etc.).
  - *Isolation des pannes* : un Prometheus local en panne n’impacte pas les autres, la vue globale manquera seulement certaines métriques le temps de la panne.
- Ne nécessite *pas de stockage objet*, *ni de micro‑services supplémentaires*.


### Limites et points de vigilance

- Pas de vrai *"single pane of glass"* sur toutes les **séries brutes** :
  - Vue globale limitée à ce qui est fédéré,
  - Bénéfique pour la scalabilité,
  - Contraignant pour certains diagnostics fins.
- **Réplication** complète des séries entre serveurs via fédération est déconseillée.
  Surcharge les Prometheus source et cible en CPU, mémoire et réseau.
- **Rétention** à long terme limitée par les capacités d’un seul nœud Prometheus pour chaque instance (locales et globale).
- **Haute disponibilité** nécessite des mécanismes complémentaires (Prometheus redondants par DC + mécanisme de bascule ou d’équilibrage).


### Schéma type pour DC01 / DC02 / Master

- `DC01` : Prometheus DC01 scrape toutes les cibles locales (VM, pods, équipements, lab de formation, etc.).
- `DC02` : Prometheus DC02 avec le même rôle côté DC02.
- Master : configure :
  - un job **`/federate`** avec cibles DC01 et DC02, et
  - des **`match[]`** ne remontant que des *agrégats ou métriques clés*.
    Exemple : `job="*"` agrégé par service, client ou session de formation).

Ce modèle couvre bien un besoin de monitoring centralisé pour une entreprise de formation tant que la volumétrie reste raisonnable et que la rétention à long terme n’est pas critique.


## Thanos


### Principe et composants

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


### Avantages

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


### Limites et complexité

- Nécessite un **\*stockage objet** accessible par tous les datacenters*
  Implique des questions de *latence*, de *coûts* et de*sécurité\*.
- **Plusieurs services supplémentaires** à *déployer*, *monitorer* et *mettre à jour*
  Querier, Store Gateway, Compactor, Ruler, éventuellement Receivers.
  Augmente la complexité opérationnelle par rapport à la simple fédération.
- Le **dimensionnement et la configuration** (*topologie*, *flags*, *stratégies de downsampling et de rétention*) demandent des compétences spécifiques en observabilité à grande échelle.


### Schéma type pour DC01 / DC02 / Master

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


## Cortex


### Principe et architecture

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


### Avantages

- **Multi‑tenant natif**
  - Isolation des métriques par tenant,
  - Idéal pour une plateforme partagée entre plusieurs clients ou équipes (ex. : chaque client formation ou chaque promo comme tenant distinct).
- **Scalabilité horizontale fine**
  Distributeurs, ingesters, queriers et frontends peuvent être *mis à l'échelle indépendamment* selon la charge (ingest vs lecture).
- **Haute disponibilité**
  Les échantillons sont répliqués sur plusieurs ingesters, et le système supporte la perte de nœuds individuels sans perte globale de données.
- **Rétention longue** durée similaire à Thanos via stockage objet.


### Limites et complexité

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


### Schéma type pour DC01 / DC02 / Master

- DC01 et DC02 :
  - Chaque Prometheus local scrape ses cibles comme d’habitude.
  - Remote‑write vers l’endpoint Cortex exposé (par exemple via un load balancer Nginx ou Ingress), en taguant l’ID de tenant.[2]
- Couche centrale Cortex (pouvant être dans un DC ou répartie) :
  - Ensemble Distributor / Ingester / Querier / Query Frontend / Compactor connecté à un stockage objet partagé.[15][2]
  - Grafana se connecte directement à Cortex pour les requêtes.

Pour une entreprise de formation, ce modèle est pertinent si l’objectif est de faire de la supervision multi‑tenant « as a service » (par client, par université, par promo) à grande échelle, en acceptant une complexité d’exploitation proche d’une plateforme SaaS.


## Grafana Mimir


### Principe et architecture

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


### Avantages

- **Multi‑tenant** et **hautement scalable**
  Similaire à Cortex, tout en bénéficiant des efforts d’*optimisation* récents de Grafana Labs (par exemple sur la pipeline de requêtage et la gestion des blocks).
- Intégration naturelle avec l’**écosystème Grafana** (Dashboards, Alerting, Tempo, Loki, etc.).
- Fonctionnalités avancées
  - Ingestion d’*échantillons out‑of‑order* (expérimental),
  - Options d’ingestion via WarpStream pour la scalabilité, etc.


### Limites et complexité

- **Complexité opérationnelle** comparable à Cortex
  - nombreux services à déployer et surveiller,
  - dépendance à un stockage objet et à un KV store.
- Encore plus orienté vers les opérateurs de grandes plateformes d’observabilité (Grafana Cloud‑like) que vers de petits environnements multi‑DC.
- *Pas encore de downsampling intégré* (proposition encore en discussion)
  Peut impacter les coûts et performances pour des rétentions très longues avec fort volume.


### Schéma type pour DC01 / DC02 / Master

- DC01 / DC02 :
  - Prometheus locaux avec `remote‑write` vers un *endpoint Mimir mutualisé*.
- Couche centrale Mimir :
  - Ensemble complet Distributor / Ingester / Store Gateway / Compactor / Querier / Query Frontend connectés au stockage objet.
  - Grafana (et éventuellement le Prometheus Master si conservé) se branche sur Mimir pour les queries.


## Tableau comparatif synthétique

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


## Recommandations pour une entreprise de formation avec deux DC


### Quand privilégier la fédération Prometheus

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


### Quand envisager Thanos

Thanos devient intéressant si un ou plusieurs de ces critères sont vrais :

- Besoin de **rétention long terme** (plusieurs mois/années) pour les métriques des labs, des plateformes LMS, ou pour des *analyses pédagogiques à long terme*.
- Exigences de **haute disponibilité** fortes, avec tolérance à la perte d’un DC ou d’un Prometheus *sans perte significative d’observabilité*.
- **Volumétrie croissante** (multiplication des environnements de formation, labs dynamiques Kubernetes, etc.).

Implémentation suggérée :

- Garder l’architecture avec un Prometheus par DC, mais *ajouter un sidecar* Thanos.
- Déployer un *stockage objet mutualisé* (par exemple MinIO multi‑site) accessible depuis DC01 et DC02.
- Déployer Thanos Querier, Store Gateway, Compactor et éventuellement Ruler dans le DC le plus fiable.
- Optionnel : conserver un Prometheus Master fédéré pour certaines vues spécifiques, mais déporter la majorité des dashboards sur Thanos Querier.


### Quand privilégier Cortex ou Mimir

Cortex ou Mimir se justifient surtout dans des scénarios où l’entreprise de formation :

- Devient un *fournisseur de plateforme* d’observabilité pour de multiples clients, universités ou partenaires, avec un *modèle multi‑tenant explicite*.
- Souhaite centraliser la collecte de métriques de *dizaines/centaines de clusters ou environnements* de labs, avec une *croissance rapide de la cardinalité*.
- Dispose d’une *équipe SRE/plateforme* capable d’opérer une *stack micro‑services complexe* et un *cluster Kubernetes robuste*.

Entre Cortex et Mimir :

- Cortex offre un modèle éprouvé et neutre, largement utilisé pour des déploiements enterprise et dans plusieurs clouds.
- Mimir, étroitement couplé à Grafana, propose des optimisations et une intégration plus poussée à l’écosystème Grafana, au prix d’un alignement plus fort avec ce vendor.

Pour un simple besoin de deux datacenters avec un Master, ces solutions risquent d’être surdimensionnées et coûteuses à opérer, sauf si la stratégie d’entreprise prévoit clairement une montée en charge multi‑tenant de type SaaS.

Voici une version enrichie du tableau comparatif avec les deux nouveaux axes demandés.


## Conclusion

Pour une entreprise de formation disposant de deux datacenters et d’un Prometheus central, la hiérarchie par fédération Prometheus représente généralement l’architecture la plus simple et suffisante, tant que le volume de métriques et les besoins de rétention restent raisonnables.
Thanos constitue une évolution naturelle lorsque les besoins en rétention longue durée, haute disponibilité et vue multi‑DC détaillée s’intensifient.

Cortex et Grafana Mimir sont, eux, adaptés aux opérateurs de plateformes d’observabilité multi‑tenant à très grande échelle et ne se justifient vraiment que si l’entreprise vise ce type de modèle ou si la volumétrie et la diversité des environnements de formation explosent.

- Pour un contexte avec seulement deux datacenters (DC01, DC02) et un Prometheus central, la **fédération** reste la solution la plus adaptée, car elle est simple à comprendre, à déployer et à maintenir.
- Elle permet d’avoir une vue globale sur les métriques clés via le Prometheus Master, tout en gardant la collecte détaillée et l’isolation des pannes au niveau de chaque DC.
- Thanos ajoute rétention long terme, vue globale complète et déduplication entre réplicas, mais au prix d’un stockage objet partagé et de plusieurs services supplémentaires à opérer, ce qui est souvent surdimensionné pour deux DC de formation.
- Cortex et Mimir ciblent des plateformes multi‑tenant massivement scalables, avec une architecture micro‑services nettement plus complexe, difficile à justifier sans besoin SaaS ou multi‑client à grande échelle.
- Recommandation : partir sur une fédération Prometheus hiérarchique (Prometheus DC01, Prometheus DC02, Prometheus Master) et ne considérer Thanos qu’en seconde étape si la volumétrie et la rétention long terme deviennent réellement critiques.


## Références

[1] [How to Configure Thanos with Prometheus - OneUptime](https://oneuptime.com/blog/post/2026-01-25-prometheus-thanos-configuration/view)
[2] [Scaling Prometheus with Cortex (Updated in 2024) - InfraCloud](https://www.infracloud.io/blogs/cortex-for-ha-monitoring-with-prometheus/)
[3] [How to Use Grafana Mimir for Metrics - OneUptime](https://oneuptime.com/blog/post/2026-01-27-grafana-mimir-metrics/view)
[4] [Federation | Prometheus](https://prometheus.io/docs/prometheus/latest/federation/)
[5] [Cortex Intro: Multi-Tenant Scalable Prometheus - Ben Ye & Friedrich Gonzalez](https://www.youtube.com/watch?v=by538PPSPQ0)
[6] [Learning Grafana Mimir architecture](https://at-ishikawa.github.io/2025/03/28/learning-grafana-mimir-architecture/)
[7] [Prometheus Federation Scaling Prometheus Guide | Last9](https://last9.io/blog/prometheus-federation-guide/)
[8] [Prometheus HA with Thanos sidecar or receiver? | CNCF](https://www.cncf.io/blog/2021/09/10/prometheus-ha-with-thanos-sidecar-or-receiver/)
[9] [Getting Started - Thanos](https://thanos.io/v0.4/thanos/getting-started.md/)
[10] [Federation in Prometheus: Scaling Across Multiple Clusters](https://platformengineer.hashnode.dev/federation-in-prometheus-scaling-across-multiple-clusters)
[11] [How to Implement Prometheus Federation Hierarchies - OneUptime](https://oneuptime.com/blog/post/2026-02-02-prometheus-federation-hierarchies/view)
[12] [Thanos Sidecarthanos.io › tip › components › sidecar](https://thanos.io/tip/components/sidecar.md/)
[13] [Grafana Mimir compactor](https://grafana.com/docs/mimir/latest/references/architecture/components/compactor/)
[14] [Cortex Intro: Multi-Tenant Scalable Prometheus - Charlie Le, Apple & Daniel Blando, Amazon](https://www.youtube.com/watch?v=OGAEWCoM6Tw)
[15] [What Is Cortex? Scalable, Multi-Tenant Storage for Prometheus Metrics](https://www.youtube.com/watch?v=ZMBcBxb1Uys)

[1] [Querier/Query - Thanos](https://thanos.io/tip/components/query.md/)
[2] [Need clarification on Thanos Query deduplication Behaviour · thanos-io thanos · Discussion #7128](https://github.com/thanos-io/thanos/discussions/7128)
[3] [Cortex Architecture](https://cortexmetrics.io/docs/architecture/)
[4] [Configure Grafana Mimir high-availability deduplication](https://grafana.com/docs/mimir/latest/configure/configure-high-availability-deduplication/)
[5] [Grafana Mimir distributor](https://grafana.com/docs/mimir/latest/references/architecture/components/distributor/)
[6] [Capacity Planning - Cortex](https://cortexmetrics.io/docs/guides/capacity-planning/)
[7] [Configure Grafana Mimir zone-aware replication](https://grafana.com/docs/mimir/latest/configure/configure-zone-aware-replication/)
[8] [Offline deduplication with two replica labels · thanos-io thanos · Discussion #5087](https://github.com/thanos-io/thanos/discussions/5087)
[9] [The result of "Use Deduplication" is not as expected #7586 - GitHub](https://github.com/thanos-io/thanos/issues/7586)
[10] [Cortex seems to miscalculate quorum when one ingester is unhealthy](https://github.com/cortexproject/cortex/issues/4654)
[11] [Replica de-duplication for long term storage · Issue #2362 ... - GitHub](https://github.com/thanos-io/thanos/issues/2362)
[12] [Scaling Prometheus: How we're pushing Cortex blocks storage to its ...](https://grafana.com/blog/scaling-prometheus-how-were-pushing-cortex-blocks-storage-to-its-limit-and-beyond/)
[13] [Grafana Mimir configuration parameters](https://grafana.com/docs/mimir/latest/configure/configuration-parameters/)
[14] [Zone Aware Replication - Cortex Metrics](https://cortexmetrics.io/docs/guides/zone-aware-replication/)
[15] [How to Use Grafana Mimir for Metrics - OneUptime](https://oneuptime.com/blog/post/2026-01-27-grafana-mimir-metrics/view)

[1] [Federation | Prometheus](https://prometheus.io/docs/prometheus/latest/federation/)
[2] [Prometheus Federation Scaling Prometheus Guide | Last9](https://last9.io/blog/prometheus-federation-guide/)
[3] [How to Configure Thanos with Prometheus - OneUptime](https://oneuptime.com/blog/post/2026-01-25-prometheus-thanos-configuration/view)
[4] [Prometheus HA with Thanos sidecar or receiver? | CNCF](https://www.cncf.io/blog/2021/09/10/prometheus-ha-with-thanos-sidecar-or-receiver/)
[5] [Scaling Prometheus with Cortex (Updated in 2024) - InfraCloud](https://www.infracloud.io/blogs/cortex-for-ha-monitoring-with-prometheus/)
[6] [Learning Grafana Mimir architecture](https://at-ishikawa.github.io/2025/03/28/learning-grafana-mimir-architecture/)
[7] [How to Use Grafana Mimir for Metrics - OneUptime](https://oneuptime.com/blog/post/2026-01-27-grafana-mimir-metrics/view)


<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=fr,en : -->
