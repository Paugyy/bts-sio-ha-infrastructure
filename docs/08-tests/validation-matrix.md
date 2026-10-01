# Matrice de validation

## Légende des statuts

| Statut | Signification |
|--------|---------------|
| ✅ Validé | Test exécuté, résultat conforme, **preuve archivée** dans `evidence/` |
| 🟡 Déclaré | Fonctionnalité réalisée dans le lab (roadmap cochée), **preuve à produire et archiver** |
| ⬜ À exécuter | Test jamais exécuté ou à rejouer depuis la dernière modification |
| ❌ Échec | Test exécuté, résultat non conforme — incident ouvert |

> Les statuts ci-dessous sont **initialisés d'après l'avancement déclaré du projet** (roadmap du README). Aucun test n'est marqué ✅ tant que sa preuve n'est pas présente dans [evidence/](../../evidence/README.md). Mettre à jour cette page à chaque campagne.

Campagne : `AAAA-MM-JJ` — commit : `<COMMIT>` — opérateur : `<OPERATEUR>`

## Matrice

| ID | Composant | Test | Commande | Résultat attendu | Statut | Preuve |
|----|-----------|------|----------|------------------|--------|--------|
| T01 | Réseau | Passerelles et hôtes joignables | ADM-01 : `scripts/validation/check-network.sh` | 4 passerelles, 8 hôtes, ports autorisés ouverts | 🟡 Déclaré | `01-pfsense-vlans.png`, `*-T01-network.txt` |
| T02 | SSH | Connexion par clé sur chaque VM | ADM-01 : `ssh -o BatchMode=yes mysql01 hostname` | Connexion sans mot de passe ; mot de passe refusé | ⬜ À exécuter | `*-T02-ssh.txt` |
| T03 | MariaDB | Service actif, écoute sur l'IP vBDD | MYSQL-0X : `ss -ltnp \| grep 3306` | `10.0.20.X:3306` sur les 3 nœuds | 🟡 Déclaré | `*-T04-T07-mysql0X.txt` |
| T04 | Galera | Taille du cluster | MYSQL-0X : `check-galera.sh` | `wsrep_cluster_size = 3` | 🟡 Déclaré | `03-galera-cluster-size.png` |
| T05 | Galera | Composant primaire | MYSQL-0X : `check-galera.sh` | `wsrep_cluster_status = Primary` | 🟡 Déclaré | `03-galera-cluster-size.png` |
| T06 | Galera | Nœud synchronisé | MYSQL-0X : `check-galera.sh` | `wsrep_local_state_comment = Synced` | 🟡 Déclaré | `04-galera-synced.png` |
| T07 | Galera | Nœud prêt | MYSQL-0X : `check-galera.sh` | `wsrep_ready = ON` | 🟡 Déclaré | `04-galera-synced.png` |
| T08 | Galera | Réplication multi-maître | INSERT sur chaque nœud, SELECT sur les autres ([procédure](../03-galera/validation.md)) | Données identiques sur les 3 nœuds | 🟡 Déclaré | `*-T08-replication.txt` |
| T09 | HAProxy SQL | Connexion SQL via HAProxy | WEB-01 : `mariadb -h 10.0.10.2 -u wordpress -p -e 'SELECT @@hostname'` | Réponse d'un nœud Galera | 🟡 Déclaré | `*-T09-sql.txt` |
| T10 | HAProxy SQL | Répartition round-robin | HAPROXY : `test-sql-round-robin.sh -n 9` | 3 nœuds distincts, 0 erreur | ⬜ À exécuter | `*-T10-sql-round-robin.txt` |
| T11 | WordPress | WEB-01 répond | ADM-01 : `curl -I http://10.0.10.1` | HTTP 200/30x | 🟡 Déclaré | `06-wordpress-web01.png` |
| T12 | WordPress | WEB-02 répond | ADM-01 : `curl -I http://10.0.10.4` | HTTP 200/30x | 🟡 Déclaré | `07-wordpress-web02.png` |
| T13 | HAProxy HTTP | Répartition HTTP | ADM-01 : `check-wordpress.sh` | HAProxy UP, alternance `X-Served-By` | 🟡 Déclaré | `05-haproxy-status.png` |
| T14 | Failover | Panne WEB-01 | WEB-01 : `sudo systemctl stop apache2` ; ADM-01 : `curl -I http://10.0.10.2` | 0 erreur, `X-Served-By: WEB-02` | 🟡 Déclaré | `08-failover-web01-down.png` |
| T15 | Failover | Panne WEB-02 | WEB-02 : `sudo systemctl stop apache2` ; ADM-01 : `curl -I http://10.0.10.2` | 0 erreur, `X-Served-By: WEB-01` | 🟡 Déclaré | `09-failover-web02-down.png` |
| T16 | Failover | Réintégration d'un backend | `sudo systemctl start apache2` ; ADM-01 : `curl -I http://10.0.10.2` | Alternance rétablie en ≤ 10 s, sans action sur HAProxy | ⬜ À exécuter | `*-failover-web01.log` |
| T17 | GLPI | GLPI via HAProxy | ADM-01 : `check-glpi.sh` | UP direct et via `:8080` | 🟡 Déclaré | `10-glpi.png` |
| T18 | NAT | Publication WAN | Poste labo : `curl -I http://10.4.0.198:8081` | HTTP 200/30x, `X-Served-By` présent | 🟡 Déclaré | `*-T18-nat.txt` |
| T19 | Firewall | Flux interdits bloqués | vUSER : `nc -zv -w 3 10.0.20.1 3306` (et [liste](network-tests.md#t19--filtrage-flux-interdits)) | Timeout sur chaque flux interdit | ⬜ À exécuter | `02-pfsense-firewall-vweb.png`, `*-T19-firewall.txt` |
| T20 | Galera | Perte d'un nœud | HAPROXY : `test-galera-node.sh --node 3` | `size = 2`, `Primary`, SQL OK ; retour `size = 3` | ⬜ À exécuter | `*-T20-galera-node.txt` |

## Synthèse

| Statut | Nombre |
|--------|--------|
| ✅ Validé | 0 |
| 🟡 Déclaré | 15 |
| ⬜ À exécuter | 5 |
| ❌ Échec | 0 |

Objectif avant soutenance : **20 ✅**, chaque preuve rangée selon la convention de [evidence/README.md](../../evidence/README.md).
