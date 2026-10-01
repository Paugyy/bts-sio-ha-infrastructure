# Ordre de déploiement

L'ordre suit les **dépendances** : le réseau avant les serveurs, la base avant les applications, les tests à la fin. Chaque étape se termine par un **point de contrôle** à valider avant de passer à la suivante.

```text
Proxmox ─► pfSense ─► VLAN ─► MYSQL-01 ─► MYSQL-02 ─► MYSQL-03 ─► Galera ─► HAProxy
   ─► WEB-01 ─► WEB-02 ─► WordPress ─► GLPI ─► NAT ─► Firewall ─► Tests ─► Failover
```

| # | Étape | VM | Documentation | Point de contrôle |
|---|-------|----|---------------|-------------------|
| 1 | Proxmox / VM | Hôte | [requirements.md](requirements.md) | 10 VM créées, bridge VLAN-aware |
| 2 | pfSense | pfSense | [02-pfsense/installation.md](../02-pfsense/installation.md) | Interface web accessible, WAN `10.4.0.198` |
| 3 | VLAN | pfSense, toutes | [02-pfsense/vlans.md](../02-pfsense/vlans.md) | Chaque VM pingue sa passerelle `.254` |
| 4 | MYSQL-01 | MYSQL-01 | [03-galera/mysql01.md](../03-galera/mysql01.md) | MariaDB installé, `bind-address = 10.0.20.1` |
| 5 | MYSQL-02 | MYSQL-02 | [03-galera/mysql02.md](../03-galera/mysql02.md) | MariaDB installé, `bind-address = 10.0.20.2` |
| 6 | MYSQL-03 | MYSQL-03 | [03-galera/mysql03.md](../03-galera/mysql03.md) | MariaDB installé, `bind-address = 10.0.20.3` |
| 7 | Galera | MYSQL-01/02/03 | [03-galera/bootstrap.md](../03-galera/bootstrap.md) | `check-galera.sh` : 4/4 OK sur chaque nœud |
| 8 | HAProxy | HAPROXY | [04-haproxy/installation.md](../04-haproxy/installation.md) | `haproxy -c` valide, `test-sql-round-robin.sh` : 3 nœuds |
| 9 | WEB-01 | WEB-01 | [05-wordpress/web01.md](../05-wordpress/web01.md) | Apache + PHP, `curl -I http://10.0.10.1` |
| 10 | WEB-02 | WEB-02 | [05-wordpress/web02.md](../05-wordpress/web02.md) | Apache + PHP, `curl -I http://10.0.10.4` |
| 11 | WordPress | WEB-01 puis WEB-02 | [05-wordpress/wordpress.md](../05-wordpress/wordpress.md) | Site identique sur les deux, via `10.0.10.2` |
| 12 | GLPI | GLPI-01 | [06-glpi/installation.md](../06-glpi/installation.md) | GLPI via `10.0.10.2:8080` |
| 13 | NAT | pfSense | [02-pfsense/nat.md](../02-pfsense/nat.md) | `http://10.4.0.198:8081` affiche WordPress |
| 14 | Firewall | pfSense | [02-pfsense/firewall-rules.md](../02-pfsense/firewall-rules.md) | Flux autorisés OK, flux interdits bloqués |
| 15 | Tests | ADM-01, HAPROXY | [08-tests/test-plan.md](../08-tests/test-plan.md) | Matrice T01 à T13, T17 à T19 |
| 16 | Failover | ADM-01, HAPROXY | [08-tests/wordpress-failover.md](../08-tests/wordpress-failover.md) | T14, T15, T16, T20 |

## Pourquoi cet ordre ?

- **Le réseau d'abord** : sans VLAN ni routage, aucune VM ne peut joindre les dépôts Debian ni ses voisines.
- **Les 3 nœuds MariaDB avant Galera** : on vérifie d'abord chaque MariaDB isolément (installation, `bind-address`), puis on forme le cluster. Diagnostiquer un nœud seul est bien plus simple qu'un cluster.
- **Galera avant HAProxy** : le health-check SQL de HAProxy a besoin de nœuds qui répondent.
- **HAProxy avant WordPress** : WordPress se connecte à la base **via** HAProxy (`DB_HOST = 10.0.10.2:3306`) dès l'assistant d'installation.
- **WordPress installé une seule fois** (sur WEB-01) : la base est partagée ; WEB-02 reçoit une copie des fichiers.
- **NAT et filtrage strict à la fin** : on ouvre d'abord largement pour installer, puis on restreint et on **re-teste** (beaucoup de pannes apparaissent à ce moment-là).

## Bascule vers l'exploitation

Une fois les 16 étapes validées :

1. Remplir la [matrice de validation](../08-tests/validation-matrix.md) et archiver les preuves dans [evidence/](../../evidence/README.md).
2. Effectuer une première sauvegarde ([10-backup-recovery](../10-backup-recovery/strategy.md)).
3. Créer un **snapshot Proxmox** de toutes les VM (état de référence).
4. Taguer le dépôt (`v1.0.0`).
