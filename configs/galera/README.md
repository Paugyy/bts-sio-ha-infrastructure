# Configurations Galera

Deux fichiers par nœud, déposés dans `/etc/mysql/mariadb.conf.d/` :

| Nœud | IP | `50-server.cnf` | `60-galera.cnf` |
|------|----|-----------------|-----------------|
| MYSQL-01 | 10.0.20.1 | [exemple](mysql01/50-server.cnf.example) | [exemple](mysql01/60-galera.cnf.example) |
| MYSQL-02 | 10.0.20.2 | [exemple](mysql02/50-server.cnf.example) | [exemple](mysql02/60-galera.cnf.example) |
| MYSQL-03 | 10.0.20.3 | [exemple](mysql03/50-server.cnf.example) | [exemple](mysql03/60-galera.cnf.example) |

## Ce qui change d'un nœud à l'autre

| Paramètre | Fichier | MYSQL-01 | MYSQL-02 | MYSQL-03 |
|-----------|---------|----------|----------|----------|
| `bind-address` | 50-server.cnf | 10.0.20.1 | 10.0.20.2 | 10.0.20.3 |
| `wsrep_node_address` | 60-galera.cnf | 10.0.20.1 | 10.0.20.2 | 10.0.20.3 |
| `wsrep_node_name` | 60-galera.cnf | MYSQL-01 | MYSQL-02 | MYSQL-03 |

Tout le reste (`wsrep_cluster_name`, `wsrep_cluster_address`, `wsrep_sst_method`, `binlog_format`…) est **strictement identique**.

```bash
# SUR MYSQL-02 (exemple)
sudo cp configs/galera/mysql02/50-server.cnf.example /etc/mysql/mariadb.conf.d/50-server.cnf
sudo cp configs/galera/mysql02/60-galera.cnf.example /etc/mysql/mariadb.conf.d/60-galera.cnf
```

La CI vérifie que `bind-address` et `wsrep_node_address` sont cohérents pour chaque nœud.

Paramètres expliqués : [docs/03-galera/concepts.md](../../docs/03-galera/concepts.md)
