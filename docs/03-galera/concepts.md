# Galera — Concepts

## Ce que fait Galera

**MariaDB Galera Cluster** transforme plusieurs serveurs MariaDB en un cluster **multi-maître synchrone** :

- **multi-maître** : chaque nœud accepte lectures **et** écritures ;
- **synchrone** (« virtuellement synchrone ») : au `COMMIT`, la transaction est diffusée à tous les nœuds et **certifiée** avant d'être confirmée au client. Une transaction confirmée ne peut pas être perdue par la panne d'un nœud ;
- **automatique** : un nœud qui revient se resynchronise seul (IST ou SST).

Comparaison avec la réplication classique MariaDB (primaire / réplique asynchrone) :

| Critère | Réplication asynchrone | Galera |
|---------|------------------------|--------|
| Écritures | Primaire seul | Tous les nœuds |
| Perte possible si le primaire tombe | Oui (transactions non encore répliquées) | Non |
| Bascule | Manuelle ou outil externe | Implicite (les autres nœuds sont déjà à jour) |
| Latence d'écriture | Faible | + 1 aller-retour réseau entre nœuds |
| Moteur | Tous | **InnoDB uniquement** |

## Cycle d'une écriture

<p align="center"><img src="../../diagrams/galera-flow.svg" alt="Flux de réplication Galera" width="750"></p>

1. Le client écrit sur MYSQL-02 (choisi par HAProxy).
2. Au `COMMIT`, MYSQL-02 diffuse le *write-set* (lignes modifiées) aux autres nœuds (port 4567).
3. Chaque nœud **certifie** le write-set : conflit avec une transaction concurrente ? Le résultat est déterministe et identique partout.
4. Certifiée : la transaction est validée sur MYSQL-02 et appliquée sur MYSQL-01 et MYSQL-03.
5. Conflit : le client reçoit une erreur `Deadlock found` et doit rejouer la transaction.

## Paramètres de configuration

| Paramètre | Valeur | Rôle |
|-----------|--------|------|
| `wsrep_on` | `ON` | Active la réplication Galera |
| `wsrep_provider` | `/usr/lib/galera/libgalera_smm.so` | Bibliothèque Galera (paquet `galera-4`) |
| `wsrep_cluster_name` | `mon_cluster_galera` | Nom du cluster ; **identique** sur tous les nœuds, sinon refus d'adhésion |
| `wsrep_cluster_address` | `gcomm://10.0.20.1,10.0.20.2,10.0.20.3` | Membres à contacter au démarrage ; **identique** partout |
| `wsrep_node_address` | IP du nœud | Adresse annoncée aux autres membres |
| `wsrep_node_name` | `MYSQL-0X` | Nom lisible (journaux, `wsrep_incoming_addresses`) |
| `wsrep_sst_method` | `rsync` | Méthode de transfert complet ; nécessite `rsync` sur tous les nœuds |
| `binlog_format` | `ROW` | Réplication des **lignes** modifiées (et non des requêtes), seule méthode déterministe |
| `default_storage_engine` | `InnoDB` | Seul moteur transactionnel répliqué de manière fiable (MyISAM : non) |
| `innodb_autoinc_lock_mode` | `2` | Mode *interleaved* : pas de verrou de table pour AUTO_INCREMENT, indispensable au multi-maître |

Galera ajuste aussi `auto_increment_increment` et `auto_increment_offset` (`wsrep_auto_increment_control = ON`) : avec 3 nœuds, MYSQL-01 génère des identifiants 1, 4, 7…, MYSQL-02 2, 5, 8… — aucun doublon possible entre nœuds.

## Ports

| Port | Usage | Quand |
|------|-------|-------|
| 3306 | Connexions client SQL | Permanent |
| 4567 | Communication de groupe et réplication | Permanent |
| 4568 | IST — *Incremental State Transfer* | Retour d'un nœud brièvement absent |
| 4444 | SST — *State Snapshot Transfer* | Nouveau nœud ou nœud trop en retard |

## États d'un nœud (`wsrep_local_state_comment`)

| État | Signification | Peut servir ? |
|------|---------------|---------------|
| `Joining` | En cours d'adhésion | Non |
| `Joiner` | Reçoit un SST/IST | Non |
| `Donor/Desynced` | Envoie un SST à un autre nœud (bloqué pendant `rsync`) | Non |
| `Joined` | Données reçues, rattrape le retard | Non |
| `Synced` | À jour | **Oui** |

## Quorum et split-brain

Le cluster reste **Primary** tant qu'un groupe de nœuds représente **strictement plus de 50 %** des membres du dernier état connu.

- Avec **2 nœuds**, la perte de l'un laisse 50 % : **pas de quorum**. Pire, en cas de coupure réseau entre les deux, chacun voit 50 % et les deux s'arrêtent. Deux nœuds n'apportent donc pas de tolérance aux pannes.
- Avec **3 nœuds**, un nœud isolé (33 %) passe en `non-Primary` et refuse les requêtes, pendant que les deux autres (67 %) continuent. Aucune divergence possible : c'est la protection contre le **split-brain**.

Un arrêt **propre** (`systemctl stop`) est annoncé au cluster, qui recalcule sa taille : 3 → 2 → 1 nœud restant reste Primary. Une **disparition brutale** (crash, coupure réseau) n'est pas annoncée : c'est là que le quorum s'applique.

## Limites à connaître

- Tables sans clé primaire : à éviter (réplication inefficace, risques de divergence).
- Transactions très volumineuses : limitées par `wsrep_max_ws_size`.
- Verrous explicites (`LOCK TABLES`) : non supportés en multi-maître.
- La performance d'écriture est limitée par le nœud le plus lent (contrôle de flux).
