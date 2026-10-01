# MYSQL-01 — 10.0.20.1

Premier nœud. **Candidat au bootstrap** lors de la création initiale du cluster.

## Fiche

| Élément | Valeur |
|---------|--------|
| Nom de VM | MYSQL-01 |
| IP / masque | 10.0.20.1/24 |
| Passerelle | 10.0.20.254 |
| VLAN | 302 — vBDD |
| OS | Debian 12 |
| Logiciels | MariaDB 10.11, Galera 4, rsync |
| Configurations | [50-server.cnf.example](../../configs/galera/mysql01/50-server.cnf.example), [60-galera.cnf.example](../../configs/galera/mysql01/60-galera.cnf.example) |

## Valeurs spécifiques à ce nœud

```ini
# /etc/mysql/mariadb.conf.d/50-server.cnf
bind-address            = 10.0.20.1

# /etc/mysql/mariadb.conf.d/60-galera.cnf
wsrep_node_address       = "10.0.20.1"
wsrep_node_name          = "MYSQL-01"
```

Tout le reste est identique sur les trois nœuds.

## Déploiement

**SUR MYSQL-01**

```bash
# Réseau
ip -4 addr show | grep 10.0.20.1

# Paquets et configuration (simulation, puis --apply)
sudo ./scripts/install/install-galera.sh --node-name MYSQL-01 --node-ip 10.0.20.1
sudo ./scripts/install/install-galera.sh --node-name MYSQL-01 --node-ip 10.0.20.1 --apply

# Vérifier les fichiers
grep -E '^bind-address' /etc/mysql/mariadb.conf.d/50-server.cnf
grep -E '^wsrep_node_(address|name)' /etc/mysql/mariadb.conf.d/60-galera.cnf
```

## Démarrage

Lors de la **création initiale** du cluster uniquement :

```bash
# SUR MYSQL-01
sudo galera_new_cluster
```

En fonctionnement normal ou après une panne : `sudo systemctl start mariadb`, **jamais** `galera_new_cluster` (voir [bootstrap.md](bootstrap.md) et [recovery.md](recovery.md)).

## Vérification

**SUR MYSQL-01**

```bash
sudo ss -ltnp | grep -E ':(3306|4567)'     # 3306 sur 10.0.20.1, 4567 sur 0.0.0.0
./scripts/validation/check-galera.sh
```

Attendu : `wsrep_cluster_size = 3`, `Primary`, `Synced`, `wsrep_ready = ON`.

Capture attendue (au moins un nœud) : `evidence/screenshots/03-galera-cluster-size.png`
