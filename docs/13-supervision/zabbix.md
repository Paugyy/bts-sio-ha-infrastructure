# Supervision Zabbix 7.0 LTS

> Procédure rédigée le 15/10/2026, **mise à jour le 06/11/2026** : la même VM héberge aussi le collecteur **Rsyslog** (514) et **LogAnalyzer** (second site Apache sur 8085) → [Rsyslog et LogAnalyzer](rsyslog-loganalyzer.md). Le site Zabbix (port 80, `/zabbix/`) n'est pas modifié. VM concernée : fiche ZABBIX ([plan d'adressage](../01-architecture/ip-addressing.md)).
> Aucun secret : les mots de passe sont remplacés par des marque-places `<MOT_DE_PASSE_…>`.

Installer Zabbix 7.0 LTS sur ZABBIX-01, stocker sa base sur le cluster Galera via HAProxy, puis superviser les VM par agent : 5 étapes, chacune avec sa vérification.

## Machines et flux

| Machine | IP | Rôle |
| --- | --- | --- |
| sio2527-ZABBIX-ypaugy | 10.0.30.3 | Serveur Zabbix (Debian 12, VLAN 303) |
| sio2527-HAPROXY-ypaugy | 10.0.10.2 | Accès SQL au cluster, port 3306 |
| sio2527-MYSQL-01-ypaugy | 10.0.20.1 | Nœud Galera 1, sert à créer la base |
| sio2527-MYSQL-02-ypaugy | 10.0.20.2 | Nœud Galera 2 |
| sio2527-MYSQL-03-ypaugy | 10.0.20.3 | Nœud Galera 3 |
| sio2527-fw-01-ypaugy | WAN 10.4.0.198 | pfSense, publie le Web Zabbix sur le port 2231, le SSH sur 2232 (et LogAnalyzer sur 2233 depuis le 06/11, [flux pfSense](pfsense-flux-journalisation.md)) |

**Flux :** ZABBIX-01 → pfSense → HAProxy:3306 → Galera pour la base ; ZABBIX-01 → pfSense → agents:10050 pour les métriques.

## 1. pfSense : autoriser Zabbix

**SUR sio2527-fw-01-ypaugy — interface Web** → *Firewall / Rules / vADMIN*, règles placées **au-dessus** de DEFAULT-DENY.

| # | Action | Source | Destination | Port | Pourquoi |
| --- | --- | --- | --- | --- | --- |
| 1 | PASS | 10.0.30.3 | 10.0.10.0/24 | TCP 10050 | Agents du VLAN Web |
| 2 | PASS | 10.0.30.3 | 10.0.20.0/24 | TCP 10050 | Agents des nœuds Galera |
| 3 | PASS | 10.0.30.3 | 10.0.10.2 | TCP 3306 | Base Zabbix via HAProxy |

Pour l'import du schéma (étape 3) seulement : PASS 10.0.30.3 → 10.0.20.1 TCP 3306, à désactiver ensuite.

> **ATTENTION** — Ne jamais publier 10050, 10051, 3306, 514 (Syslog) ni UDP 161 sur le WAN.

## 2. Base de données

**SUR sio2527-MYSQL-01-ypaugy — 10.0.20.1** (Galera réplique sur les 3 nœuds)

```sql
CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER 'zabbix'@'10.0.30.3' IDENTIFIED BY '<MOT_DE_PASSE_ZABBIX_DB>';
CREATE USER 'zabbix'@'10.0.10.2' IDENTIFIED BY '<MOT_DE_PASSE_ZABBIX_DB>';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'10.0.30.3';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'10.0.10.2';
SET GLOBAL log_bin_trust_function_creators = 1;
```

Deux comptes : `10.0.30.3` pour l'import en direct, `10.0.10.2` parce que MariaDB voit l'IP de HAProxy quand Zabbix passe par lui.

## 3. Installer Zabbix

**SUR sio2527-ZABBIX-ypaugy — 10.0.30.3** — dépôt, paquets, import du schéma (une seule fois, en entier)

```bash
wget https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_latest_7.0+debian12_all.deb
sudo dpkg -i zabbix-release_latest_7.0+debian12_all.deb
sudo apt update
sudo apt install zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent2 mariadb-client
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -h 10.0.20.1 -u zabbix -p zabbix
```

**SUR sio2527-ZABBIX-ypaugy — 10.0.30.3** — fichier `/etc/zabbix/zabbix_server.conf`

```ini
DBHost=10.0.10.2
DBName=zabbix
DBUser=zabbix
DBPassword=<MOT_DE_PASSE_ZABBIX_DB>
```

**SUR sio2527-ZABBIX-ypaugy — 10.0.30.3** — locales, fuseau, services

```bash
sudo apt install locales
sudo sed -i -e 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' -e 's/^# *fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/' /etc/locale.gen
sudo locale-gen
sudo timedatectl set-timezone Europe/Paris
sudo systemctl restart zabbix-server zabbix-agent2 apache2
sudo systemctl enable zabbix-server zabbix-agent2 apache2
```

**Assistant Web :** `http://10.4.0.198:2231/zabbix` → base MySQL, hôte `10.0.10.2`, port `3306`, base et utilisateur `zabbix`, **TLS décoché**, fuseau Europe/Paris. Changer ensuite le mot de passe du compte `Admin` (`<MOT_DE_PASSE_ADMIN>`).

> **RÉSULTAT ATTENDU** — 203 tables dans la base `zabbix`, tableau de bord Zabbix accessible. Désactiver la règle temporaire vers 10.0.20.1:3306.

## 4. Installer les agents

**SUR chaque VM Linux — exemple : sio2527-MYSQL-01-ypaugy — 10.0.20.1** (dépôt Zabbix ajouté comme à l'étape 3)

```bash
sudo apt install zabbix-agent2
```

Fichier `/etc/zabbix/zabbix_agent2.conf` :

```ini
Server=10.0.30.3
ServerActive=10.0.30.3
Hostname=sio2527-MYSQL-01-ypaugy
```

```bash
sudo systemctl restart zabbix-agent2
sudo systemctl enable zabbix-agent2
```

`Hostname` doit être exactement le nom de la VM, celui qui sera saisi dans Zabbix.

## 5. Ajouter les hôtes et vérifier

**SUR sio2527-ZABBIX-ypaugy — 10.0.30.3 — interface Web** → *Data collection / Hosts / Create host* : *Host name* = hostname exact de la VM, interface *Agent* `IP:10050`, template *Linux by Zabbix agent*.

| Test | Machine | Commande | Attendu |
| --- | --- | --- | --- |
| Agent joignable | sio2527-ZABBIX-ypaugy — 10.0.30.3 | `zabbix_get -s 10.0.20.1 -p 10050 -k agent.ping` (paquet `zabbix-get`) | `1` |
| Base via HAProxy | sio2527-ZABBIX-ypaugy — 10.0.30.3 | `mysql -h 10.0.10.2 -u zabbix -p -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='zabbix';"` | `203` |
| Cluster sain | sio2527-MYSQL-01-ypaugy — 10.0.20.1 | `sudo mysql -e "SHOW STATUS LIKE 'wsrep_cluster_size';"` | `3` |
| Hôte supervisé | Interface Web Zabbix | *Data collection / Hosts* | Icône **ZBX** verte |
| Site Zabbix intact après ajout de LogAnalyzer | sio2527-ZABBIX-ypaugy — 10.0.30.3 | `curl -I http://127.0.0.1/zabbix/` | `200` (relevé le 06/11) |

## Pièges déjà rencontrés

| Symptôme | Solution |
| --- | --- |
| `ERROR 1050 : Table 'role' already exists` | Import partiel : `DROP DATABASE zabbix;` puis `CREATE DATABASE` et réimport complet |
| `ERROR 1419 : SUPER privilege` | `SET GLOBAL log_bin_trust_function_creators = 1;` plutôt que donner SUPER au compte |
| « MySQL server has gone away » dans l'assistant | Décocher le chiffrement TLS de la base |
| Locale `en_US` absente | `locale-gen` puis redémarrer Apache |
| Fichier SQL introuvable | Bon chemin : `/usr/share/zabbix-sql-scripts/mysql/server.sql.gz` |
| Icône ZBX rouge, « timed out » | Règle pfSense manquante ou placée sous DEFAULT-DENY |
| Doute après l'ajout d'un second site Apache (8085) | `sudo apache2ctl -S` liste les deux sites ; `reload` plutôt que `restart` ; `/zabbix/` doit répondre `200` |
