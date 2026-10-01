# Scripts

Scripts Bash d'installation, de validation, de test de bascule et de sauvegarde.

## Principes

| Principe | Mise en œuvre |
|----------|---------------|
| Lisibles et commentés | En-tête : rôle, machine cible, actions, ce que le script **ne fait pas** |
| Mode strict | `set -euo pipefail` dans tous les scripts exécutables |
| Sans secret | Mots de passe demandés à l'exécution (`read -s`) et placés dans un fichier temporaire `600` supprimé à la sortie |
| Non destructifs par défaut | Installation : **simulation** sauf `--apply` ; failover : **mode guidé** sauf `--auto` ; sauvegarde : **aucune suppression** sauf `--retention` |
| Idempotents | Un paquet installé, un module actif ou un fichier déjà correct n'est pas retouché |
| Sortie normalisée | `[INFO]`, `[OK]`, `[WARN]`, `[FAIL]` + bilan ; code retour `0` = succès, `1` = échec, `2` = erreur d'usage |
| Jamais de bootstrap automatique | Aucun script n'exécute `galera_new_cluster` |

## Inventaire

| Script | Machine | Rôle |
|--------|---------|------|
| **install/** | | |
| [install-galera.sh](install/install-galera.sh) | MYSQL-0X | Paquets Galera, `bind-address`, `60-galera.cnf` |
| [install-haproxy.sh](install/install-haproxy.sh) | HAPROXY | Paquets, contrôle du compte système `haproxy` |
| [install-wordpress-deps.sh](install/install-wordpress-deps.sh) | WEB-01, WEB-02 | Apache, PHP, modules ; `--download` WordPress vérifié par SHA-1 |
| [install-glpi-deps.sh](install/install-glpi-deps.sh) | GLPI-01 | Apache, PHP et extensions GLPI 10 |
| **validation/** | | |
| [check-galera.sh](validation/check-galera.sh) | MYSQL-0X ou HAPROXY | `cluster_size`, `Primary`, `Synced`, `wsrep_ready` |
| [check-haproxy.sh](validation/check-haproxy.sh) | HAPROXY | Service, syntaxe, ports, état des backends |
| [check-wordpress.sh](validation/check-wordpress.sh) | ADM-01 | UP/DOWN + code HTTP de WEB-01, WEB-02, HAProxy |
| [check-glpi.sh](validation/check-glpi.sh) | ADM-01 | GLPI direct et via HAProxy :8080 |
| [check-network.sh](validation/check-network.sh) | ADM-01 | Passerelles, hôtes, ports autorisés |
| [check-repository.sh](validation/check-repository.sh) | Poste dev / CI | Structure, secrets, permissions, syntaxe |
| **failover/** | | |
| [test-web01-failure.sh](failover/test-web01-failure.sh) | ADM-01 → WEB-01 | Bascule HTTP quand WEB-01 tombe |
| [test-web02-failure.sh](failover/test-web02-failure.sh) | ADM-01 → WEB-02 | Bascule HTTP quand WEB-02 tombe |
| [test-galera-node.sh](failover/test-galera-node.sh) | HAPROXY → MYSQL-0X | Perte et retour d'un nœud Galera |
| **backup/** | | |
| [backup-mariadb.sh](backup/backup-mariadb.sh) | MYSQL-03 | `mariadb-dump` cohérent, compressé, empreinte |
| [backup-wordpress.sh](backup/backup-wordpress.sh) | WEB-01 | Archive des fichiers WordPress |
| **utilities/** | | |
| [show-cluster-status.sh](utilities/show-cluster-status.sh) | HAPROXY | Tableau d'état des 3 nœuds (`-w 5` : rafraîchi) |
| [test-sql-round-robin.sh](utilities/test-sql-round-robin.sh) | HAPROXY / WEB-0X | `SELECT @@hostname` répété via HAProxy |
| **lib/** | | |
| [common.sh](lib/common.sh) | — | Affichage, compteurs, simulation, accès MariaDB, sondes HTTP |
| [failover.sh](lib/failover.sh) | — | Procédure de bascule web partagée |

## Déploiement des scripts sur une VM

```bash
# SUR ADM-01 : copier le dépôt sur la VM cible (exemple : HAPROXY)
rsync -av --exclude .git ./ haproxy:~/bts-sio-ha-infrastructure/

# SUR HAPROXY
cd ~/bts-sio-ha-infrastructure
./scripts/validation/check-haproxy.sh
```

## Exemple de sortie

```text
============================================================
Script        : check-galera.sh
Rôle          : Contrôle de l'état Galera
Machine cible : MYSQL-01 / MYSQL-02 / MYSQL-03
Exécuté sur   : mysql01
============================================================
[INFO] Checking Galera status on local...
[INFO] Nœud : MYSQL-01
[OK]   wsrep_cluster_size = 3
[OK]   wsrep_cluster_status = Primary
[OK]   wsrep_local_state_comment = Synced
[OK]   wsrep_ready = ON
[OK]   wsrep_connected = ON
```

> Cette sortie illustre le format attendu ; elle n'est pas une preuve d'exécution. Les sorties réelles sont archivées dans [evidence/test-results/](../evidence/README.md).

## Qualité

```bash
# SUR LE POSTE DE DÉVELOPPEMENT
make lint-sh      # shellcheck -x sur tous les scripts
make check        # check-repository.sh
```

Sous Windows, Git n'enregistre pas le bit exécutable automatiquement :

```bash
git update-index --chmod=+x scripts/*/*.sh
```
