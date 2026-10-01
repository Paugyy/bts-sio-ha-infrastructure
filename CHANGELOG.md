# Changelog

Toutes les évolutions notables de ce projet sont consignées dans ce fichier.

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/), versionnement [SemVer](https://semver.org/lang/fr/).

## [Unreleased]

### Prévu

- HAProxy secondaire + Keepalived (IP virtuelle).
- Health-check Galera *wsrep-aware*.
- HTTPS.
- Supervision et sauvegardes automatisées.

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
