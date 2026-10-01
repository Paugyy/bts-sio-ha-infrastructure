# Présentation orale

Trame proposée pour une présentation d'environ **20 minutes** suivie des questions du jury. Adapter la durée au format de l'épreuve.

## Déroulé

| Temps | Partie | Contenu | Support |
|-------|--------|---------|---------|
| 0:00 | Contexte | Organisation, besoin, problème du serveur unique | [project-context.md](../00-overview/project-context.md) |
| 2:00 | Objectifs | Les 10 objectifs mesurables | [objectives.md](../00-overview/objectives.md) |
| 4:00 | Architecture | Schéma, VLAN, plan d'adressage | [architecture.svg](../../diagrams/architecture.svg) |
| 7:00 | Choix techniques | Pourquoi Galera, 3 nœuds, HAProxy, VLAN | [jury-questions.md](jury-questions.md) |
| 10:00 | **Démonstration** | Voir ci-dessous | Terminal + page de stats |
| 15:00 | Difficultés | 2 ou 3 incidents réels et leur résolution | [incidents.md](../09-troubleshooting/incidents.md) |
| 17:00 | Limites et SPOF | HAProxy, pfSense, Proxmox, fichiers WordPress | [spof-analysis.md](../01-architecture/spof-analysis.md) |
| 19:00 | Bilan | Compétences, améliorations | [project-retrospective.md](project-retrospective.md) |

## Démonstration (5 minutes)

**Préparation** (avant l'oral) : toutes les VM démarrées, `check-galera.sh` et `check-wordpress.sh` OK, snapshot Proxmox, deux terminaux sur ADM-01, page de stats HAProxy ouverte, site WordPress ouvert.

| # | Action | Ce que le jury voit | Message |
|---|--------|---------------------|---------|
| 1 | **SUR ADM-01** boucle `curl` (voir [wordpress-failover.md](../08-tests/wordpress-failover.md)) | Alternance `WEB-01` / `WEB-02` | « La charge est répartie » |
| 2 | **SUR WEB-01** `sudo systemctl stop apache2` | Uniquement `WEB-02`, aucune erreur ; WEB-01 rouge dans les stats | « La panne est invisible pour l'utilisateur » |
| 3 | **SUR WEB-01** `sudo systemctl start apache2` | Retour de l'alternance | « Réintégration automatique » |
| 4 | **SUR HAPROXY** `./scripts/utilities/show-cluster-status.sh` | 3 nœuds Primary / Synced | « La base est répliquée sur 3 nœuds » |
| 5 | **SUR MYSQL-03** `sudo systemctl stop mariadb` puis recharger WordPress | Site fonctionnel, `cluster_size = 2` | « Le quorum 2/3 est conservé » |
| 6 | **SUR MYSQL-03** `sudo systemctl start mariadb` | Retour à 3 | « Il rejoint seul, sans bootstrap » |

**Plan B** si la démonstration échoue : captures de [evidence/](../../evidence/README.md) et sorties archivées. Ne jamais improviser un bootstrap Galera devant le jury.

## Conseils

- Montrer le **schéma** en permanence ou y revenir souvent.
- Annoncer les **limites** soi-même avant que le jury ne les trouve : c'est un signe de maîtrise.
- Distinguer clairement ce qui est **réalisé**, **testé** et **prévu**.
- Utiliser le vocabulaire exact : quorum, health-check, SPOF, RPO/RTO, deny-by-default.
