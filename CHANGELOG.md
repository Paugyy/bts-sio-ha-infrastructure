# Changelog

Toutes les évolutions notables de ce projet sont consignées dans ce fichier.

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/), versionnement [SemVer](https://semver.org/lang/fr/).

## [Unreleased]

### Prévu

- HAProxy secondaire + Keepalived (IP virtuelle).
- Health-check Galera *wsrep-aware*.
- HTTPS.
- Alertes Zabbix, journaux de pfSense et des postes Windows, sauvegardes automatisées.

## [1.1.0] — 2026-11-06

### Ajouté

- **Supervision** : VM ZABBIX (`10.0.30.3`), Zabbix 7.0 LTS, 12 hôtes ; publication `WAN:2231`.
- **Journalisation centralisée** : Rsyslog (TCP/UDP 514) sur ZABBIX, envoi automatique depuis les 8 VM Linux (`omfwd` TCP avec file d'attente), LogAnalyzer 5.0.2 sur le port 8085 publié par `WAN:2233` pour les réseaux d'administration.
- Section [docs/13-supervision/](docs/13-supervision/rsyslog-loganalyzer.md), exemples `configs/rsyslog/`, `configs/apache/loganalyzer-8085.conf.example`, `configs/logrotate/`.
- Schéma `diagrams/journalisation.svg`, tests T21 à T35, incidents LOG-01 à LOG-10.

### Modifié

- Plan d'adressage : ADM-01 (contrôleur de domaine AD, Windows Server 2022), ZABBIX, CLI-01 ; NAT relus sur la configuration réelle (8082 vers GLPI-01 en direct, 2223 à 2233).
- Schémas mis à jour (ZABBIX, CLI-01, flux Syslog, valeurs mesurées : contrôle toutes les 2 s, bascule 9 s) ; `vmbr0`.
- README : section « Écarts entre la référence et le labo » (contrôles HAProxy, SQL sur MYSQL-01 seul, pas de page 8404 ni de `X-Served-By`, fichiers WordPress non synchronisés).

## [1.0.0] — 2026-10-01

Première version publiée : **BTS SIO HA Infrastructure — Initial Release**.

### Ajouté

- **Architecture réseau** : pfSense, WAN `10.4.0.198/24`, 4 VLAN (301 vWEB, 302 vBDD, 303 vADMIN, 304 vUSER), routage inter-VLAN, règles deny-by-default, NAT `WAN:8081 → 10.0.10.2:80`.
- **Galera 3 nœuds** : MariaDB 10.11 + Galera 4, cluster `mon_cluster_galera`, SST `rsync`, configurations dédiées pour MYSQL-01/02/03.
- **HAProxy SQL** : écoute `10.0.10.2:3306`, répartition TCP round-robin, health-check `mysql-check`.
- **WordPress HA** : WEB-01 et WEB-02 derrière HAProxy (`10.0.10.2:80`), health-check HTTP, en-tête `X-Served-By`, synchronisation des fichiers par `rsync`.
- **GLPI** : GLPI-01 publié via HAProxy `:8080`, base sur le cluster Galera.
- **Documentation** : 12 sections (vue d'ensemble, architecture, pfSense, Galera, HAProxy, WordPress, GLPI, sécurité, tests, dépannage, sauvegarde, BTS SIO, gestion de projet).
- **Scripts** : installation (mode simulation par défaut), validation (Galera, HAProxy, WordPress, GLPI, réseau, dépôt), failover guidé, sauvegarde, utilitaires.
- **Générateur** HTML hors ligne pour produire une infrastructure équivalente avec d'autres paramètres.
- **Schémas** SVG : architecture, VLAN, flux WordPress, flux Galera, failover web, SPOF.
- **CI GitHub Actions** : markdownlint, ShellCheck, validation des configurations, vérification des liens.
- **Gouvernance** : SECURITY, CONTRIBUTING, CODE_OF_CONDUCT, templates d'issues et de PR, Dependabot.

### Sécurité

- Toutes les configurations sont publiées en `*.example` avec placeholders ; `.gitignore` bloque clés, secrets, sauvegardes et exports pfSense.

### Limites connues

- HAProxy, pfSense, GLPI et l'hôte Proxmox restent des points uniques de défaillance (voir [spof-analysis.md](docs/01-architecture/spof-analysis.md)).

[Unreleased]: https://github.com/<GITHUB_USER>/bts-sio-ha-infrastructure/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/<GITHUB_USER>/bts-sio-ha-infrastructure/releases/tag/v1.0.0
