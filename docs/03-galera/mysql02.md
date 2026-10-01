# MYSQL-02 — 10.0.20.2

Deuxième nœud. Rejoint le cluster après le bootstrap de MYSQL-01.

## Fiche

| Élément | Valeur |
|---------|--------|
| Nom de VM | MYSQL-02 |
| IP / masque | 10.0.20.2/24 |
| Passerelle | 10.0.20.254 |
| VLAN | 302 — vBDD |
| OS | Debian 12 |
| Logiciels | MariaDB 10.11, Galera 4, rsync |
| Configurations | [50-server.cnf.example](../../configs/galera/mysql02/50-server.cnf.example), [60-galera.cnf.example](../../configs/galera/mysql02/60-galera.cnf.example) |

## Valeurs spécifiques à ce nœud

```ini
# /etc/mysql/mariadb.conf.d/50-server.cnf
bind-address            = 10.0.20.2

# /etc/mysql/mariadb.conf.d/60-galera.cnf
wsrep_node_address       = "10.0.20.2"
wsrep_node_name          = "MYSQL-02"
```

Tout le reste est identique sur les trois nœuds.

## Déploiement

**SUR MYSQL-02**

```bash
# Réseau
ip -4 addr show | grep 10.0.20.2

# Paquets et configuration (simulation, puis --apply)
sudo ./scripts/install/install-galera.sh --node-name MYSQL-02 --node-ip 10.0.20.2
sudo ./scripts/install/install-galera.sh --node-name MYSQL-02 --node-ip 10.0.20.2 --apply

# Vérifier les fichiers
grep -E '^bind-address' /etc/mysql/mariadb.conf.d/50-server.cnf
grep -E '^wsrep_node_(address|name)' /etc/mysql/mariadb.conf.d/60-galera.cnf
```

## Démarrage

Après le bootstrap de MYSQL-01 :

```bash
# SUR MYSQL-02
sudo systemctl start mariadb
sudo journalctl -u mariadb -n 30 --no-pager     # rechercher "Synchronized with group, ready for connections"
```

## Vérification

**SUR MYSQL-02**

```bash
sudo ss -ltnp | grep -E ':(3306|4567)'     # 3306 sur 10.0.20.2, 4567 sur 0.0.0.0
./scripts/validation/check-galera.sh
```

Attendu : `wsrep_cluster_size = 3`, `Primary`, `Synced`, `wsrep_ready = ON`.

Capture attendue (au moins un nœud) : `evidence/screenshots/03-galera-cluster-size.png`
