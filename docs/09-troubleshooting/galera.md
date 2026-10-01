# Dépannage — Galera

Voir aussi : [03-galera/troubleshooting.md](../03-galera/troubleshooting.md) (arbre de décision) et [03-galera/recovery.md](../03-galera/recovery.md).

## Un nœud ne rejoint pas le cluster

| Élément | Contenu |
|---------|---------|
| **Symptôme** | `systemctl start mariadb` échoue ou reste en `Joining` ; `wsrep_cluster_size` reste à 2 sur les autres |
| **Cause probable** | Ports 4567/4568/4444 bloqués ; `rsync` absent ; `wsrep_cluster_name` différent ; espace disque insuffisant pour le SST |
| **Diagnostic** | Lire le journal du nœud **et** du donneur |
| **Commandes** | **SUR LE NŒUD** `sudo journalctl -u mariadb -n 100 --no-pager` ; `command -v rsync` ; `df -h /var/lib/mysql` ; `nc -zv 10.0.20.1 4567` ; `grep wsrep_cluster_name /etc/mysql/mariadb.conf.d/60-galera.cnf` |
| **Correction** | Installer rsync ; ouvrir les ports (nftables) ; aligner le nom du cluster ; libérer de l'espace |
| **Validation** | `check-galera.sh` : `cluster_size = 3`, `Synced` |

## Nœud bloqué en Donor/Desynced

| Élément | Contenu |
|---------|---------|
| **Symptôme** | Un nœud `Donor/Desynced` longtemps ; requêtes lentes ou bloquées sur ce nœud |
| **Cause probable** | SST rsync en cours vers un nœud qui rejoint : le donneur est verrouillé pendant la copie |
| **Diagnostic** | Un autre nœud est en `Joiner` ? |
| **Commandes** | **SUR HAPROXY** `./scripts/utilities/show-cluster-status.sh -w 5` |
| **Correction** | Attendre la fin du SST. Pour éviter le blocage : `wsrep_sst_method = mariabackup` (paquet `mariadb-backup`, compte SST dédié) |
| **Validation** | Les deux nœuds reviennent `Synced` |

## Conflits d'écriture (Deadlock)

| Élément | Contenu |
|---------|---------|
| **Symptôme** | Erreurs applicatives intermittentes `ERROR 1213 (40001): Deadlock found when trying to get lock` |
| **Cause probable** | Deux transactions concurrentes modifient la même ligne via deux nœuds différents : la seconde échoue à la certification |
| **Commandes** | **SUR UN NŒUD** `sudo mariadb -e "SHOW STATUS LIKE 'wsrep_local_cert_failures'"` |
| **Correction** | Passer HAProxy SQL en **écrivain unique** (variante commentée de `haproxy.cfg.example`) |
| **Validation** | `wsrep_local_cert_failures` n'augmente plus |

## Taille de cluster incohérente entre nœuds

| Élément | Contenu |
|---------|---------|
| **Symptôme** | MYSQL-01 annonce `cluster_size = 2`, MYSQL-03 annonce `1` |
| **Cause probable** | Partition réseau ou nœud bootstrappé à tort (deux clusters distincts) |
| **Commandes** | **SUR CHAQUE NŒUD** `sudo mariadb -e "SHOW STATUS LIKE 'wsrep_cluster_state_uuid'"` — UUID différents = **deux clusters** |
| **Correction** | Choisir le cluster de référence (données les plus récentes), arrêter le nœud de l'autre cluster, le redémarrer normalement pour qu'il reçoive un SST. Les écritures faites sur le cluster écarté sont **perdues** |
| **Validation** | Même `wsrep_cluster_state_uuid` et `cluster_size = 3` partout |

## MariaDB ne démarre plus après modification de configuration

| Élément | Contenu |
|---------|---------|
| **Symptôme** | `Job for mariadb.service failed` |
| **Cause probable** | Faute de frappe dans un `.cnf`, option inconnue |
| **Commandes** | `sudo journalctl -u mariadb -n 30 --no-pager` ; `sudo mariadbd --help --verbose >/dev/null` |
| **Correction** | Corriger la ligne signalée ; comparer avec `configs/galera/` |
| **Validation** | Démarrage normal, `check-galera.sh` OK |
