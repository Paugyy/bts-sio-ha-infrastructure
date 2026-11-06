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
| T21 | Supervision | Zabbix publié | Poste : `http://10.4.0.198:2231/zabbix/` | Page de connexion Zabbix | 🟡 Déclaré (200 en local le 06/11) | `*-T21-zabbix.png` |
| T22 | NAT | SSH de ZABBIX publié | Poste : `Test-NetConnection 10.4.0.198 -Port 2232` | `True` | ⬜ À exécuter | `*-T22-ssh-zabbix.txt` |
| T23 | NAT | LogAnalyzer joignable | Poste d'administration : `http://10.4.0.198:2233/` | Authentification, puis interface | 🟡 Déclaré (passé le 06/11) | `*-T23-loganalyzer.png` |
| T24 | Apache | Authentification LogAnalyzer | ZABBIX : `curl -I http://127.0.0.1:8085/` puis avec `-u` | `401` puis `200` ; `/zabbix/` toujours `200` | 🟡 Déclaré (passé le 06/11) | `*-T24-curl.txt` |
| T25 | LogAnalyzer | Assistant et source | Poste : `/install.php` | Source `SYSLOG-CENTRAL` (*Diskfile*) | 🟡 Déclaré (passé le 06/11) | `*-T25-source.png` |
| T26 | Rsyslog | Réception locale TCP et UDP | ZABBIX : `logger` local, `tail central.log` | 2 messages de test | 🟡 Déclaré (passé le 06/11) | `*-T26-local.png` |
| T27 | Rsyslog | Envois directs des 8 VM Linux | Chaque VM : `logger -n 10.0.30.3 -P 514 -T …` | 8 lignes dans `central.log` | 🟡 Déclaré (passé le 06/11) | `*-T27-direct.png` |
| T28 | Rsyslog | Envoi automatique des 8 VM Linux | Chaque VM : `logger -t SYSLOG-AUTO …` | 8/8 dans LogAnalyzer | 🟡 Déclaré (passé le 06/11 : 8/8) | `*-T28-auto.png` |
| T29 | Rsyslog | Journaux de pfSense | pfSense : *Remote Logging* vers `10.0.30.3:514` | Hôte pfSense visible | ⬜ À exécuter | `*-T29-pfsense.png` |
| T30 | Firewall | Source non autorisée bloquée | vUSER : `Test-NetConnection 10.0.30.3 -Port 514` | `False`, refus journalisé | ⬜ À exécuter | `*-T30-bloque.txt` |
| T31 | Firewall | `DEFAULT-DENY` dernière partout | pfSense : *Firewall / Rules*, 5 onglets | `BLOCK ALL` en dernière ligne | ⬜ À exécuter | `*-T31-regles.png` |
| T32 | LogAnalyzer | Verrouillage après l'assistant | ZABBIX : `curl -I -u … /install.php` | `404` | ⬜ À exécuter | `*-T32-verrouillage.txt` |
| T33 | Rsyslog | Résilience d'un émetteur | VM pilote : redémarrage, coupure du 514 | Messages reçus après redémarrage et coupure | ⬜ À exécuter | `*-T33-resilience.txt` |
| T34 | Rsyslog | Rotation de `central.log` | ZABBIX : `logrotate -d`, puis rotation réelle | Fichier recréé `0640 root:www-data` | ⬜ À exécuter | `*-T34-logrotate.txt` |
| T35 | Rsyslog | Événements Windows | ADM-01, CLI-01 | Un événement Windows dans LogAnalyzer | ⬜ À exécuter | `*-T35-windows.png` |

## Synthèse

| Statut | Nombre |
|--------|--------|
| ✅ Validé | 0 |
| 🟡 Déclaré | 22 |
| ⬜ À exécuter | 13 |
| ❌ Échec | 0 |

T21 à T35 (ajoutés le 06/11/2026) couvrent la supervision et la journalisation centralisée : [docs/13-supervision/](../13-supervision/rsyslog-loganalyzer.md).

Objectif avant soutenance : **35 ✅**, chaque preuve rangée selon la convention de [evidence/README.md](../../evidence/README.md).
