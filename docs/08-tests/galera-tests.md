# Tests Galera

## T03 — MariaDB opérationnel

**SUR MYSQL-01, MYSQL-02, MYSQL-03**

```bash
systemctl is-active mariadb                       # active
sudo ss -ltnp | grep 3306                         # écoute sur 10.0.20.X:3306 (pas 127.0.0.1)
```

## T04 à T07 — État du cluster

**SUR MYSQL-01, MYSQL-02, MYSQL-03**

```bash
NO_COLOR=1 ./scripts/validation/check-galera.sh | tee "evidence/test-results/$(date +%F)-T04-T07-$(hostname -s).txt"
```

| Test | Variable | Attendu |
|------|----------|---------|
| T04 | `wsrep_cluster_size` | `3` |
| T05 | `wsrep_cluster_status` | `Primary` |
| T06 | `wsrep_local_state_comment` | `Synced` |
| T07 | `wsrep_ready` | `ON` |

Captures : `03-galera-cluster-size.png`, `04-galera-synced.png`

## T08 — Réplication

Procédure : [03-galera/validation.md](../03-galera/validation.md#2-réplication-test-t08)

Critère : une ligne insérée sur un nœud est lisible immédiatement sur les deux autres, dans les trois sens.

## T20 — Perte d'un nœud

### Préparation

- T03 à T10 réussis.
- Snapshot Proxmox des 3 nœuds (recommandé).
- WordPress ouvert dans un navigateur (pour observer l'absence d'impact).

### Exécution guidée

**SUR HAPROXY**

```bash
./scripts/failover/test-galera-node.sh --node 3
```

Le script indique la commande à lancer :

**SUR MYSQL-03**

```bash
sudo systemctl stop mariadb
```

### Vérifications pendant la panne

| Vérification | Attendu |
|--------------|---------|
| `wsrep_cluster_size` sur MYSQL-01 et MYSQL-02 | `2` |
| `wsrep_cluster_status` | `Primary` (2/3 = majorité) |
| SQL via HAProxy (6 connexions) | 6 succès, MYSQL-03 absent des réponses |
| Page de stats HAProxy | MYSQL-03 **DOWN** |
| WordPress | Fonctionnel |

### Retour

**SUR MYSQL-03**

```bash
sudo systemctl start mariadb          # PAS galera_new_cluster
```

| Vérification | Attendu |
|--------------|---------|
| `wsrep_cluster_size` | `3` sur les 3 nœuds |
| MYSQL-03 | `Synced` (après IST) |
| HAProxy | MYSQL-03 **UP** |

### Variante : écritures pendant la panne

Insérer des lignes pendant que MYSQL-03 est arrêté (via MYSQL-01), puis vérifier après son retour qu'il les possède : démontre l'**IST** (transfert incrémental).

## Test complémentaire (non numéroté) — perte de deux nœuds

À réaliser **uniquement** en démonstration pédagogique, avec snapshot préalable :

1. Arrêt **propre** de MYSQL-02 puis MYSQL-03 : MYSQL-01 reste `Primary` avec `cluster_size = 1` (les départs ont été annoncés).
2. Pour illustrer le quorum, il faut une disparition **non annoncée** (ex. coupure réseau de deux nœuds via Proxmox, *Hardware → Network Device → Disconnect*) : le nœud restant passe `non-Primary` et refuse les requêtes.

Reprise : [03-galera/recovery.md](../03-galera/recovery.md).
