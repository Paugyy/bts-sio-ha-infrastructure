# HAProxy — Répartition SQL

## Configuration

```haproxy
listen galera_cluster
    bind 10.0.10.2:3306
    mode tcp
    option tcplog
    balance roundrobin
    option mysql-check user haproxy_check post-41
    timeout client 30m
    timeout server 30m
    default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
    server MYSQL-01 10.0.20.1:3306 check
    server MYSQL-02 10.0.20.2:3306 check
    server MYSQL-03 10.0.20.3:3306 check
```

## Explication

| Directive | Rôle |
|-----------|------|
| `mode tcp` | HAProxy relaie les octets sans comprendre le protocole MySQL (couche 4) |
| `balance roundrobin` | Chaque **nouvelle connexion** va au nœud suivant. Une connexion ouverte reste sur son nœud |
| `option mysql-check user haproxy_check post-41` | Le health-check ouvre une vraie session MySQL (handshake + authentification) |
| `timeout client/server 30m` | Les connexions SQL peuvent rester inactives longtemps (pools, sessions GLPI) |
| `on-marked-down shutdown-sessions` | Quand un nœud est déclaré DOWN, ses sessions sont coupées : les clients se reconnectent ailleurs |

## Pourquoi passer par HAProxy plutôt qu'un nœud ?

- WordPress et GLPI n'acceptent **qu'une seule adresse** de serveur SQL.
- Si cette adresse était `10.0.20.1`, la panne de MYSQL-01 couperait les applications malgré les deux autres nœuds.
- HAProxy fournit une adresse **stable** (`10.0.10.2:3306`) et écarte automatiquement un nœud en panne.

## Round-robin ou écrivain unique ?

| Mode | Configuration | Avantage | Inconvénient |
|------|---------------|----------|--------------|
| **Round-robin** (lab) | 3 serveurs actifs | Démontre le multi-maître ; charge répartie | Deux écritures concurrentes sur la même ligne via deux nœuds → conflit de certification (`Deadlock`) |
| **Écrivain unique** (production) | 1 actif + 2 `backup` | Aucun conflit de certification | Un seul nœud travaille ; les autres attendent |

Le round-robin est conservé dans le lab pour sa valeur démonstrative (`test-sql-round-robin.sh`). Avec la charge très faible de WordPress et GLPI en lab, les conflits sont improbables. En production, la variante commentée dans [haproxy.cfg.example](../../configs/haproxy/haproxy.cfg.example) serait préférable.

## IP source et comptes SQL

HAProxy étant un proxy TCP, MariaDB voit toutes les connexions provenir de **10.0.10.2**. Les comptes applicatifs sont donc déclarés pour cet hôte :

```sql
-- SUR MYSQL-01
CREATE USER 'wordpress'@'10.0.10.2' IDENTIFIED BY '<PASSWORD>';
CREATE USER 'glpi'@'10.0.10.2'      IDENTIFIED BY '<PASSWORD>';
```

Conséquence de sécurité : MariaDB ne peut plus distinguer WEB-01 de GLPI-01. Le filtrage par source est assuré **en amont** (pfSense : seul vWEB et vADMIN atteignent `10.0.10.2:3306`).

## Vérification

```bash
# SUR HAPROXY
./scripts/utilities/test-sql-round-robin.sh -n 9
```

```text
  connexion  1 -> mysql01
  connexion  2 -> mysql02
  connexion  3 -> mysql03
  ...
[OK]   3 nœuds distincts ont répondu (round-robin effectif)
```

(Format de sortie illustratif ; le résultat réel est consigné dans la matrice, test T10.)
