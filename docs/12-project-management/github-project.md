# GitHub Project

## Tableau

Créer un projet (*Projects → New project → Board*) nommé **HA Infrastructure Roadmap**, avec les colonnes :

| Colonne | Contenu |
|---------|---------|
| **Backlog** | Idées et améliorations non planifiées |
| **Planned** | Retenues pour la prochaine version |
| **In Progress** | En cours (une branche `feature/*` existe) |
| **Testing** | Déployé en lab, tests de la matrice en cours |
| **Documentation** | Testé ; documentation et preuves en cours de rédaction |
| **Done** | Fusionné dans `main`, CHANGELOG à jour |

## Issues suggérées

| Titre | Labels | Colonne initiale | Critère de fin |
|-------|--------|------------------|----------------|
| Add HAProxy secondary node | `haproxy`, `high-availability`, `enhancement` | Planned | HAPROXY-02 opérationnel, configuration identique |
| Implement Keepalived VIP | `haproxy`, `high-availability`, `network` | Planned | VIP 10.0.10.2 bascule en < 3 s à l'arrêt du MASTER |
| Add HTTPS | `security`, `haproxy`, `enhancement` | Backlog | Terminaison TLS sur HAProxy, redirection 80 → 443 |
| Add Galera-aware health checks | `galera`, `haproxy`, `high-availability` | Planned | Nœud `Donor/Desynced` retiré de HAProxy |
| Add WordPress shared storage | `wordpress`, `high-availability` | Backlog | `uploads` identique sur les 2 nœuds sans rsync |
| Add monitoring | `enhancement`, `testing` | Backlog | Prometheus + Grafana (ou Zabbix / Centreon) : alertes nœud DOWN |
| Add automated backups | `security`, `galera`, `wordpress` | Planned | cron + copie hors hôte + rétention |
| Test disaster recovery | `testing`, `galera` | Backlog | Restauration complète sur VM de test, RTO mesuré |

## Création avec GitHub CLI

```bash
# SUR LE POSTE DE DÉVELOPPEMENT (labels créés au préalable, voir labels.md)
gh issue create --title "Add HAProxy secondary node" --label haproxy,high-availability,enhancement \
  --body "Supprimer le SPOF HAProxy (voir docs/01-architecture/spof-analysis.md). Critère : HAPROXY-02 avec configuration identique."
gh issue create --title "Implement Keepalived VIP" --label haproxy,high-availability,network \
  --body "VIP 10.0.10.2 portée par VRRP. Critère : bascule < 3 s à l'arrêt du MASTER, sans modification des clients ni du NAT."
gh issue create --title "Add HTTPS" --label security,haproxy,enhancement \
  --body "Terminaison TLS sur HAProxy, redirection HTTP vers HTTPS, X-Forwarded-Proto https."
gh issue create --title "Add Galera-aware health checks" --label galera,haproxy,high-availability \
  --body "Remplacer mysql-check par un check HTTP (port 9200) renvoyant 200 uniquement si wsrep_local_state = 4 (Synced)."
gh issue create --title "Add WordPress shared storage" --label wordpress,high-availability \
  --body "Remplacer la synchronisation rsync de wp-content/uploads par un stockage partagé (NFS, GlusterFS)."
gh issue create --title "Add monitoring" --label enhancement,testing \
  --body "Supervision Prometheus + Grafana, ou Zabbix / Centreon : état des nœuds Galera, backends HAProxy, ressources des VM."
gh issue create --title "Add automated backups" --label security,galera,wordpress \
  --body "Planifier backup-mariadb.sh et backup-wordpress.sh, copie hors de l'hôte Proxmox, rétention."
gh issue create --title "Test disaster recovery" --label testing,galera \
  --body "Restaurer base + fichiers sur une VM isolée, mesurer le RTO, archiver la preuve."
```

## Jalons (Milestones)

| Jalon | Contenu |
|-------|---------|
| `v1.1.0` | Galera-aware health checks, sauvegardes automatisées |
| `v1.2.0` | HAProxy secondaire + Keepalived |
| `v2.0.0` | HTTPS, stockage partagé, supervision |
