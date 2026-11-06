# Journalisation centralisée : Rsyslog et LogAnalyzer

> Procédure rédigée le 06/11/2026, d'après les commandes et les captures de la mise en service du même jour. VM concernée : fiche ZABBIX ([plan d'adressage](../01-architecture/ip-addressing.md)). Pare-feu : [flux pfSense](pfsense-flux-journalisation.md). Incidents et recette : [incidents](../09-troubleshooting/incidents.md).
> Aucun secret : mots de passe et comptes remplacés par `<MOT_DE_PASSE_…>`, `<COMPTE_…>`.

**Légende :** ✅ **fait et testé** (sortie de commande ou capture du 06/11) · 🟨 **proposé, non testé** (ou à confirmer sur la machine) · ⬜ **à faire**

**Pourquoi :** chaque serveur garde ses journaux chez lui. Quand une panne touche plusieurs machines, il faut ouvrir autant de sessions pour reconstituer ce qui s'est passé, et un serveur compromis peut effacer ses propres traces. On envoie donc une **copie** de chaque journal vers **un seul serveur** (Rsyslog), lisible dans un navigateur (LogAnalyzer). C'est la brique « Preuve » (traçabilité) du DICP de la réalisation 1.

**Choix :** aucune VM ni adresse en plus. Les trois services cohabitent sur `sio2527-ZABBIX-ypaugy` (`10.0.30.3`, VLAN 303), chacun sur son port : **Zabbix :80**, **LogAnalyzer :8085**, **Syslog :514**.

## État au 06/11/2026 (fin de journée de mise en service)

| Brique | Ce qui est en place | État |
|---|---|---|
| Récepteur Rsyslog TCP/UDP 514 | Écoute IPv4 et IPv6 (`ss`), messages de test reçus à 07:35 | ✅ |
| Fichier central et droits | `/var/log/remote-syslog/central.log`, `root:www-data`, `0750` / `0640` | ✅ |
| Site Apache 8085 + authentification Basic | `401` sans compte, `200` avec ; `/zabbix/` toujours `200` | ✅ |
| Liste d'adresses Apache | `403` depuis le poste d'administration corrigé en autorisant **son réseau** ; plages exactes retenues à relire | ✅ / 🟨 plages à confirmer |
| Publication `WAN:2233` → `:8085` | Interface ouverte dans Chrome depuis le poste | ✅ (règles actives à relire : [flux pfSense](pfsense-flux-journalisation.md)) |
| LogAnalyzer **5.0.2** | Assistant terminé : source `SYSLOG-CENTRAL`, type *Diskfile*, vue *Syslog Fields*, format *Syslog / RSyslog* ; base d'utilisateurs LogAnalyzer non activée | ✅ |
| Verrouillage `config.php`, neutralisation de `install.php` | Non fait | ⬜ |
| Envoi **automatique** depuis les 8 VM Linux | `SYSLOG-AUTO` visible pour les 8 machines, plus de vrais événements `sudo` et `mariadbd` | ✅ |
| Journaux de pfSense | Non configurés | ⬜ |
| Journaux Windows (adm-01, cli-01) | Méthode à choisir | ⬜ |
| Fichiers applicatifs (Apache access/error, HAProxy, GLPI…) | Non confirmés : seuls les journaux système passent | ⬜ |
| Rotation, résilience après redémarrage ou coupure, HTTPS | Non faits | ⬜ |

## Machines et flux

| Machine | IP | Rôle | Envoi |
| --- | --- | --- | --- |
| sio2527-ZABBIX-ypaugy | 10.0.30.3 | **Collecteur** Rsyslog · LogAnalyzer 8085 · Zabbix 80 | — (ne s'envoie rien à lui-même) |
| sio2527-WEB-01-ypaugy · HAPROXY · GLPI-01 · WEB-02 | 10.0.10.1 · .2 · .3 · .4 | Émetteurs vWEB | TCP 514, à travers pfSense (règle vWEB) ✅ |
| sio2527-MYSQL-01 / 02 / 03-ypaugy | 10.0.20.1 · .2 · .3 | Émetteurs vBDD | TCP 514, à travers pfSense (règle vBDD) ✅ |
| sio2527-guacamole-01-ypaugy | 10.0.30.2 | Émetteur vADMIN | TCP 514, **même VLAN** : pas de règle ✅ |
| sio2527-fw-01-ypaugy | 10.0.30.254 côté vADMIN | Émetteur prévu | UDP 514 ⬜ |
| adm-01, cli-01 (Windows) | 10.0.30.1, 10.0.40.1 | Émetteurs prévus | Méthode à choisir ⬜ |
| Poste d'administration | réseau d'administration autorisé | Lecteur LogAnalyzer | `WAN:2233` ✅ |

```text
 vWEB .1 .2 .3 .4 ─┐ TCP 514 (règle vWEB)
 vBDD .1 .2 .3 ────┼──────────► 10.0.30.3 Rsyslog ──► /var/log/remote-syslog/central.log
 guacamol .30.2 ───┘ (même VLAN)                              │ lecture www-data
 pfSense (à faire, UDP 514)                                   ▼
 Poste admin ──► 10.4.0.198:2233 ──NAT──► 10.0.30.3:8085 LogAnalyzer 5.0.2 (compte + réseau autorisé)
```

> **ATTENTION** — Ne **jamais** publier 514 (TCP ou UDP), 10050, 10051, 3306 ni UDP 161 sur le WAN. Syslog circule en clair : il reste à l'intérieur du labo.

---

## 1. Récepteur Rsyslog — ✅

**SUR sio2527-ZABBIX-ypaugy — 10.0.30.3** — fichier `/etc/rsyslog.d/10-central-receiver.conf` :

```rsyslog
module(load="imudp")
module(load="imtcp")

ruleset(name="remoteLogs") {
    action(
        type="omfile"
        file="/var/log/remote-syslog/central.log"
        template="RSYSLOG_TraditionalFileFormat"
    )
}

input(type="imudp" port="514" ruleset="remoteLogs")
input(type="imtcp" port="514" ruleset="remoteLogs")
```

Le `ruleset` sépare les messages reçus du réseau des journaux propres à la VM : ils vont **seulement** dans `central.log`.

```bash
sudo install -d -o root -g www-data -m 0750 /var/log/remote-syslog
sudo touch /var/log/remote-syslog/central.log
sudo chown root:www-data /var/log/remote-syslog/central.log && sudo chmod 0640 /var/log/remote-syslog/central.log
sudo rsyslogd -N1 && sudo systemctl restart rsyslog
```

Pas de compte `syslog` sur cette Debian ([LOG-01](../09-troubleshooting/incidents.md)) : Rsyslog tourne sous `root:root` (`ps -o user,group,cmd -C rsyslogd`). Le groupe `www-data` permet à Apache de **lire**, pas d'écrire.

| Vérification (sur 10.0.30.3) | Commande | Relevé du 06/11 |
|---|---|---|
| Écoute | `sudo ss -lntup \| grep ':514 '` | `0.0.0.0:514` et `[::]:514`, TCP et UDP ✅ |
| Réception UDP puis TCP | `logger` en local vers le port 514, puis `sudo tail central.log` | `Nov  6 07:35:37 … TEST UDP - reception fonctionnelle` et `07:35:42 … TEST TCP - reception fonctionnelle` ✅ |
| Lecture par Apache | affichage des deux messages dans LogAnalyzer | ✅ (capture du 06/11) |

## 2. Site Apache LogAnalyzer sur 8085 — ✅

**SUR sio2527-ZABBIX-ypaugy — 10.0.30.3** — Apache sert déjà Zabbix sur le port 80. On ajoute un **second port** (`Listen 8085` dans `/etc/apache2/ports.conf`) et un site dédié, `/etc/apache2/sites-available/loganalyzer-8085.conf`, qui pointe sur `/var/www/loganalyzer`. Le site Zabbix n'est pas touché.

```bash
sudo htpasswd -c /etc/apache2/.htpasswd-loganalyzer <COMPTE_LOGANALYZER>   # mot de passe demandé à l'écran, écrit nulle part
```

On exige **les deux** : un compte valide **et** une adresse source connue. Le NAT de pfSense conserve l'adresse du poste : sans son réseau dans la liste, Apache répond `403` même avec le bon compte ([LOG-05](../09-troubleshooting/incidents.md) : `AH01630: client denied by server configuration` pour le poste d'administration).

```apache
<Directory /var/www/loganalyzer>
    Options -Indexes +FollowSymLinks
    AllowOverride None
    DirectoryIndex index.php
    AuthType Basic
    AuthName "LogAnalyzer - Administration"
    AuthUserFile /etc/apache2/.htpasswd-loganalyzer
    <RequireAll>
        Require valid-user
        <RequireAny>
            Require local
            Require ip 10.0.30.0/24
            Require ip <RÉSEAU_DU_POSTE_ADMIN>      # réseau du poste d'administration
        </RequireAny>
    </RequireAll>
</Directory>
```

> 🟨 **À confirmer** : les plages réellement retenues dans le fichier. Les relire avec `grep -n "Require" /etc/apache2/sites-available/loganalyzer-8085.conf` et reporter le résultat ici. Ne **jamais** remplacer ce bloc par `Require all granted`.

```bash
sudo apache2ctl configtest        # "Syntax OK" ; l'avertissement AH00558 (nom de serveur) n'est pas bloquant
sudo systemctl reload apache2     # reload, pas restart : Zabbix n'est pas coupé
sudo ss -lntp | grep -E ':(80|8085) '
curl -I http://127.0.0.1:8085/                              # 401 Unauthorized ✅
curl -I -u <COMPTE_LOGANALYZER> http://127.0.0.1:8085/      # 200 OK (mot de passe saisi au clavier) ✅
curl -I http://127.0.0.1/zabbix/                            # 200 OK : Zabbix inchangé ✅
```

## 3. Assistant LogAnalyzer 5.0.2 — ✅ fait · ⬜ verrouillage

Avant l'assistant, l'interface affichait `Critical Error occured — main configuration file is missing!` ([LOG-06](../09-troubleshooting/incidents.md)) : c'est normal tant que `install.php` n'a pas été joué.

| # | Action | Valeur retenue | État |
|---|---|---|---|
| 1 | Ouvrir `http://10.4.0.198:2233/install.php` depuis le poste | `401`, puis assistant | ✅ |
| 2 | Base d'utilisateurs propre à LogAnalyzer | **non activée** (l'accès est protégé par Apache) | ✅ |
| 3 | Source des journaux (étape 7) | nom `SYSLOG-CENTRAL`, type **Diskfile**, format *Syslog / RSyslog*, fichier `/var/log/remote-syslog/central.log`, vue *Syslog Fields* | ✅ (capture du 06/11) |
| 4 | Afficher les messages | les deux tests TCP et UDP de 07:35 visibles | ✅ (capture du 06/11) |
| 5 | **Verrouiller** | retirer le droit d'écriture temporaire sur `config.php`, rendre `install.php` inaccessible, vérifier que les messages s'affichent toujours | ⬜ |

Proposition pour l'étape 5 (🟨 non testée) — **SUR 10.0.30.3** :

```bash
sudo chown root:www-data /var/www/loganalyzer/config.php && sudo chmod 0640 /var/www/loganalyzer/config.php
sudo mv /var/www/loganalyzer/install.php /root/loganalyzer-install.php.bak
curl -I -u <COMPTE_LOGANALYZER> http://127.0.0.1:8085/install.php    # attendu : 404
curl -I -u <COMPTE_LOGANALYZER> http://127.0.0.1:8085/               # attendu : 200, messages toujours visibles
```

## 4. Envoi depuis les 8 VM Linux — ✅

**SUR chacune des 8 VM émettrices** (WEB-01 `10.0.10.1`, WEB-02 `10.0.10.4`, HAPROXY `10.0.10.2`, GLPI-01 `10.0.10.3`, MYSQL-01/02/03 `10.0.20.1` à `.3`, guacamole-01 `10.0.30.2`) — **jamais sur zabbix**, qui se renverrait ses propres messages.

Rsyslog n'était **pas installé** sur ces Debian : le fichier de transfert seul ne faisait rien ([LOG-08](../09-troubleshooting/incidents.md)).

```bash
sudo apt update
sudo apt install -y rsyslog
sudo systemctl enable --now rsyslog
```

Fichier `/etc/rsyslog.d/90-centralisation.conf` :

```rsyslog
*.* action(
    type="omfwd"
    target="10.0.30.3"
    port="514"
    protocol="tcp"
    queue.type="LinkedList"
    queue.filename="syslog-forward"
    queue.maxDiskSpace="512m"
    queue.saveOnShutdown="on"
    action.resumeRetryCount="-1"
)
```

| Paramètre | Pourquoi |
|---|---|
| `omfwd`, `protocol="tcp"` | Copie automatique de tout ce que Rsyslog traite, en TCP : une perte de connexion se voit, au lieu de disparaître en silence comme en UDP |
| `queue.*`, `resumeRetryCount="-1"` | File d'attente sur disque (512 Mo au plus) et nouvelles tentatives sans limite si le collecteur ne répond pas. **Garanties à tester** (redémarrage, coupure du 514, arrêt brutal) : ⬜ |

```bash
sudo rsyslogd -N1                                   # syntaxe
sudo systemctl restart rsyslog && sudo systemctl status rsyslog --no-pager
grep -rl omfwd /etc/rsyslog.d/                      # une seule règle d'envoi : sinon chaque message arrive en double
```

**Deux tests différents** — ne pas les confondre :

| Test | Commande (sur la VM émettrice) | Ce qu'il prouve | Résultat du 06/11 |
|---|---|---|---|
| **Direct** | `logger -n 10.0.30.3 -P 514 -T -t TEST-WEB01 "TEST SYSLOG WEB01 - communication inter-VLAN OK"` | Le réseau et pfSense laissent passer le 514 (n'utilise **pas** Rsyslog) | ✅ 8 VM (capture du 06/11) |
| **Automatique** | `logger -t SYSLOG-AUTO "TEST AUTOMATIQUE DEPUIS $(hostname)"` | Rsyslog local transmet **tout seul** ce qu'il reçoit | ✅ **8/8** (capture du 06/11) |

**Contrôle — uniquement SUR sio2527-ZABBIX-ypaugy — 10.0.30.3** (le fichier central n'existe pas sur les émetteurs : [LOG-07](../09-troubleshooting/incidents.md)) :

```bash
sudo grep 'TEST AUTOMATIQUE DEPUIS' /var/log/remote-syslog/central.log
```

| VM | IP | `SYSLOG-AUTO` visible |
|---|---|---|
| sio2527-WEB-01-ypaugy | 10.0.10.1 | ✅ |
| sio2527-WEB-02-ypaugy | 10.0.10.4 | ✅ |
| sio2527-HAPROXY-ypaugy | 10.0.10.2 | ✅ |
| sio2527-GLPI-01-ypaugy | 10.0.10.3 | ✅ |
| sio2527-MYSQL-01-ypaugy | 10.0.20.1 | ✅ |
| sio2527-MYSQL-02-ypaugy | 10.0.20.2 | ✅ |
| sio2527-MYSQL-03-ypaugy | 10.0.20.3 | ✅ |
| sio2527-guacamole-01-ypaugy | 10.0.30.2 | ✅ |

La même capture montre de **vrais** événements `sudo` (plusieurs serveurs) et `mariadbd` (MYSQL-01) : la collecte ne se limite pas aux messages de test. Elle ne prouve pas que les fichiers applicatifs (Apache access/error, HAProxy, GLPI) sont collectés.

## 5. Restant à faire — ⬜

| # | Travail | Où | Preuve attendue |
|---|---|---|---|
| 1 | Journaux de pfSense vers `10.0.30.3:514/UDP` | fw-01 : [flux pfSense §5](pfsense-flux-journalisation.md#5-envoi-des-journaux-de-pfsense-à-faire) | Hôte pfSense visible dans LogAnalyzer |
| 2 | Journaux Windows (adm-01, cli-01) | Méthode à choisir (agent Syslog pour Windows, ou transfert des événements avec relais) ; **pas** de commande `apt` sur Windows | Un événement Windows réel dans LogAnalyzer |
| 3 | Résilience des 8 émetteurs | Une VM pilote : redémarrage, puis `logger -t SYSLOG-AUTO` ; coupure du 514 puis rétablissement | Messages arrivés après le redémarrage et après la coupure |
| 4 | Rotation de `central.log` | 10.0.30.3, proposition ci-dessous | `logrotate -d` puis une vraie rotation en maintenance |
| 5 | Verrouillage LogAnalyzer | §3, étape 5 | `install.php` → `404` |
| 6 | Accès chiffré | Tunnel SSH, VPN (réalisation 2) ou HTTPS | Plus d'identifiants en clair |
| 7 | Fichiers applicatifs | Choisir les fichiers utiles (Apache, HAProxy, GLPI) sans doublon ni donnée sensible | Lignes de ces fichiers dans LogAnalyzer |

**Rotation proposée** (🟨 non testée) — fichier `/etc/logrotate.d/remote-syslog` sur 10.0.30.3 ; 26 semaines ≈ 6 mois, durée des journaux de connexion du dossier de la réalisation 1 :

```text
/var/log/remote-syslog/central.log {
    weekly
    rotate 26
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root www-data
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate
    endscript
}
```

```bash
sudo logrotate -d /etc/logrotate.d/remote-syslog   # simulation
df -h / && sudo du -sh /var/log/remote-syslog       # place restante et volume réel, à noter chaque semaine
```

Tunnel SSH en attendant le VPN (🟨) — la source vue par Apache est alors `127.0.0.1`, autorisée par `Require local` :

```powershell
# SUR le poste d'administration Windows
ssh -p 2232 -L 18085:127.0.0.1:8085 <COMPTE_SSH>@10.4.0.198     # puis http://127.0.0.1:18085/
```

## 6. Sécurité et exploitation

| Risque | Mesure | État |
|---|---|---|
| Identifiants LogAnalyzer en clair (HTTP Basic sans TLS) | Accès de **labo provisoire** ; sources restreintes dans pfSense et Apache ; cible : tunnel SSH, VPN ou HTTPS | ⬜ chiffrement |
| Journaux lisibles par trop de monde | `central.log` en `0640 root:www-data` ; le compte `zabbix` est refusé (voulu, LOG-02) | ✅ |
| Disque plein | Rotation ; déclencheur Zabbix d'espace disque du modèle Linux | ⬜ rotation |
| Syslog en clair entre zones | Flux interne au labo ; aucun NAT 514 | ✅ pas de NAT · TLS non prévu |
| Une seule VM pour supervision **et** journaux | Les émetteurs mettent en file ; séparation des fonctions à étudier | risque assumé |
| Journaux = données personnelles (adresses, comptes) | Accès réservé aux administrateurs, durée limitée (RGPD) | ✅ accès · ⬜ durée |
| `Aborted connection … to db: 'zabbix'` sur MYSQL-01 | Événement observé, **pas** une panne : surveiller sa fréquence ([OBS-11](../09-troubleshooting/incidents.md)) | à surveiller |

## Retour arrière

| Ce qu'on annule | Commande |
|---|---|
| Liste d'adresses Apache (10.0.30.3) | Remettre le bloc `Require` précédent (copie `.bak` avant toute modification), `apache2ctl configtest`, `systemctl reload apache2` |
| Site 8085 complet (10.0.30.3) | `sudo a2dissite loganalyzer-8085 && sudo systemctl reload apache2` (et retirer `Listen 8085`) — Zabbix reste sur 80 |
| Récepteur Rsyslog (10.0.30.3) | `sudo mv /etc/rsyslog.d/10-central-receiver.conf /root/ && sudo systemctl restart rsyslog` |
| Envoi depuis un serveur (sur cette VM) | `sudo mv /etc/rsyslog.d/90-centralisation.conf /root/ && sudo systemctl restart rsyslog` |
| pfSense | [flux pfSense §6](pfsense-flux-journalisation.md#6-retour-arrière) |

## Diagnostic par symptôme

| Symptôme | Cause probable | Premier contrôle |
|---|---|---|
| `Test-NetConnection 10.4.0.198 -Port 2233` : `False` | NAT 2233 absent, poste hors de la source autorisée, règle sous `BLOCK ALL` | pfSense : *Firewall / NAT*, *Rules / WAN*, *Status / System Logs / Firewall* |
| HTTP **401** | Apache est atteint : saisir le compte | — |
| HTTP **403** | Réseau du poste absent de `Require ip` | `loganalyzer-error.log` : `AH01630` et l'adresse refusée |
| `main configuration file is missing!` | Assistant pas encore joué | §3 |
| HTTP **500** | Erreur PHP | `loganalyzer-error.log` ; ne pas modifier pfSense à l'aveugle |
| `No such file or directory` sur `central.log` | Commande lancée sur un **émetteur** | Lire le fichier sur 10.0.30.3 |
| `rsyslogd: command not found` sur un émetteur | Paquet Rsyslog absent | `apt install rsyslog` (§4) |
| Rien de WEB-01 dans `central.log` | Rsyslog arrêté, règle vWEB absente | test **direct** d'abord (réseau), puis test **automatique** (Rsyslog) |
| Zabbix ne répond plus sur 2231 | Site 80 modifié par erreur | `sudo apache2ctl -S` ; restaurer le site Zabbix |
