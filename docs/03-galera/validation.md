# Galera — Validation

## 1. État du cluster

**SUR MYSQL-01, MYSQL-02, MYSQL-03**

```bash
./scripts/validation/check-galera.sh
```

Ou manuellement :

```bash
sudo mariadb -e "SHOW GLOBAL STATUS WHERE Variable_name IN
  ('wsrep_cluster_size','wsrep_cluster_status','wsrep_local_state_comment','wsrep_ready');"
```

| Variable | Attendu | Test |
|----------|---------|------|
| `wsrep_cluster_size` | `3` | T04 |
| `wsrep_cluster_status` | `Primary` | T05 |
| `wsrep_local_state_comment` | `Synced` | T06 |
| `wsrep_ready` | `ON` | T07 |

Vue d'ensemble depuis HAProxy :

```bash
# SUR HAPROXY
./scripts/utilities/show-cluster-status.sh
```

## 2. Réplication (test T08)

Créer une donnée sur un nœud, la lire sur les deux autres.

**SUR MYSQL-01**

```sql
-- sudo mariadb
CREATE DATABASE IF NOT EXISTS ha_test;
CREATE TABLE IF NOT EXISTS ha_test.replication (
  id INT AUTO_INCREMENT PRIMARY KEY,
  origin VARCHAR(20) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
INSERT INTO ha_test.replication (origin) VALUES ('MYSQL-01');
```

**SUR MYSQL-02**

```sql
SELECT * FROM ha_test.replication;              -- la ligne MYSQL-01 est présente
INSERT INTO ha_test.replication (origin) VALUES ('MYSQL-02');
```

**SUR MYSQL-03**

```sql
SELECT * FROM ha_test.replication;              -- les deux lignes sont présentes
INSERT INTO ha_test.replication (origin) VALUES ('MYSQL-03');
```

**SUR MYSQL-01**

```sql
SELECT * FROM ha_test.replication ORDER BY id;  -- 3 lignes ; ids non consécutifs (1, 2, 3 ou 1, 5, 9…)
```

Les identifiants non consécutifs sont **normaux** : chaque nœud utilise son propre décalage AUTO_INCREMENT pour éviter les collisions.

Nettoyage :

```sql
-- SUR N'IMPORTE QUEL NŒUD (répliqué partout)
DROP DATABASE ha_test;
```

## 3. Accès via HAProxy (tests T09, T10)

```bash
# SUR HAPROXY
./scripts/utilities/test-sql-round-robin.sh -n 9
```

Attendu : 3 noms d'hôte distincts, 3 connexions chacun.

## 4. Perte d'un nœud (test T20)

```bash
# SUR HAPROXY
./scripts/failover/test-galera-node.sh --node 3
```

Procédure détaillée : [08-tests/galera-tests.md](../08-tests/galera-tests.md)
