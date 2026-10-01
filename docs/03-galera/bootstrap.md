# Galera — Bootstrap

Le **bootstrap** crée un **nouveau** cluster à partir d'un seul nœud. Les autres nœuds le rejoignent ensuite et reçoivent ses données.

> **Règle absolue** : on ne bootstrappe qu'**un seul** nœud, **une seule fois**, et seulement quand **aucun** nœud du cluster n'est en fonctionnement. Bootstrapper un deuxième nœud crée un **deuxième cluster** indépendant : les données divergent (split-brain volontaire). Aucun script de ce dépôt n'automatise cette opération.

## Quand bootstrapper ?

| Situation | Bootstrap ? | Action |
|-----------|-------------|--------|
| Création initiale du cluster | **Oui**, sur MYSQL-01 | `galera_new_cluster` |
| Un nœud redémarre, les autres tournent | **Non** | `systemctl start mariadb` |
| Les 3 nœuds ont été arrêtés proprement | **Oui**, sur le dernier arrêté (`safe_to_bootstrap: 1`) | Voir [recovery.md](recovery.md) |
| Les 3 nœuds ont crashé (coupure électrique) | **Oui**, sur le nœud au `seqno` le plus élevé, après analyse | Voir [recovery.md](recovery.md) |
| Cluster `non-Primary` mais nœuds en marche | **Non** — on ne redémarre rien | Voir [recovery.md](recovery.md#perte-de-quorum-sans-arrêt) |

## Procédure de création initiale

### Étape 1 — Tous les nœuds arrêtés

**SUR MYSQL-01, MYSQL-02, MYSQL-03**

```bash
sudo systemctl stop mariadb
systemctl is-active mariadb        # attendu : inactive
```

### Étape 2 — Bootstrap de MYSQL-01

**SUR MYSQL-01**

```bash
sudo galera_new_cluster
sudo mariadb -e "SHOW STATUS LIKE 'wsrep_cluster_size';"     # attendu : 1
sudo mariadb -e "SHOW STATUS LIKE 'wsrep_cluster_status';"   # attendu : Primary
```

`galera_new_cluster` démarre MariaDB avec `--wsrep-new-cluster` : le nœud ne cherche pas de pairs et devient le cluster.

### Étape 3 — Ajout de MYSQL-02

**SUR MYSQL-02**

```bash
sudo systemctl start mariadb
sudo mariadb -e "SHOW STATUS LIKE 'wsrep_cluster_size';"     # attendu : 2
```

MYSQL-02 contacte les adresses de `wsrep_cluster_address`, trouve MYSQL-01 et reçoit un **SST** (copie complète via rsync, port 4444).

### Étape 4 — Ajout de MYSQL-03

**SUR MYSQL-03**

```bash
sudo systemctl start mariadb
sudo mariadb -e "SHOW STATUS LIKE 'wsrep_cluster_size';"     # attendu : 3
```

### Étape 5 — Retour de MYSQL-01 en mode normal

MYSQL-01 a été démarré « en mode bootstrap » par `galera_new_cluster`. Le redémarrer normalement est **facultatif** mais permet de vérifier que tout le cluster démarre avec la configuration standard :

**SUR MYSQL-01**

```bash
sudo systemctl restart mariadb
sudo mariadb -e "SHOW STATUS LIKE 'wsrep_cluster_size';"     # attendu : 3
```

## Validation

**SUR CHAQUE NŒUD**

```bash
./scripts/validation/check-galera.sh
```

Puis le test de réplication : [validation.md](validation.md).

## Erreurs fréquentes

| Message | Cause | Correction |
|---------|-------|------------|
| `It may not be safe to bootstrap the cluster from this node` | `safe_to_bootstrap: 0` dans `grastate.dat` | Vérifier que c'est le bon nœud ([recovery.md](recovery.md)) |
| `failed to open gcomm backend connection: 110` | Aucun pair joignable et pas de bootstrap | Normal pour le premier nœud : utiliser `galera_new_cluster` |
| `rsync: command not found` côté donneur ou receveur | Paquet manquant | `sudo apt install rsync` sur tous les nœuds |
