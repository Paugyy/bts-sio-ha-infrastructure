# Documentation

Documentation technique complète de l'infrastructure. Les sections sont numérotées dans l'ordre logique de lecture **et** de déploiement.

## Conventions

### Machine cible

Chaque commande précise la VM sur laquelle elle s'exécute :

**SUR MYSQL-01**

```bash
sudo systemctl status mariadb
```

Dans les blocs de code, la machine est indiquée en commentaire : `# SUR HAPROXY`.

### Nature de l'information

| Marqueur | Signification |
|----------|---------------|
| **Réel** | Configuration ou résultat effectivement en place dans le lab |
| **Exemple** | Valeur illustrative ou fichier `.example` à adapter |
| **À tester** | Procédure de test à exécuter ; résultat à consigner dans la [matrice](08-tests/validation-matrix.md) |
| **Futur** | Amélioration prévue, non réalisée (voir la roadmap du [README](../README.md#roadmap)) |

### Secrets

Les mots de passe apparaissent sous la forme `<PASSWORD>` ou `<SECRET>`. Voir [07-security/secrets-management.md](07-security/secrets-management.md).

## Sommaire

### 00 — Vue d'ensemble

- [Contexte du projet](00-overview/project-context.md)
- [Objectifs](00-overview/objectives.md)
- [Prérequis](00-overview/requirements.md)
- [Ordre de déploiement](00-overview/deployment-order.md)
- [Glossaire](00-overview/glossary.md)

### 01 — Architecture

- [Vue d'ensemble de l'architecture](01-architecture/architecture-overview.md)
- [Topologie réseau](01-architecture/network-topology.md)
- [Plan d'adressage](01-architecture/ip-addressing.md)
- [Conception des VLAN](01-architecture/vlan-design.md)
- [Flux réseau](01-architecture/network-flows.md)
- [Haute disponibilité](01-architecture/high-availability.md)
- [Analyse des SPOF](01-architecture/spof-analysis.md)

### 02 — pfSense

- [Installation](02-pfsense/installation.md) · [Interfaces](02-pfsense/interfaces.md) · [VLAN](02-pfsense/vlans.md) · [Règles de filtrage](02-pfsense/firewall-rules.md) · [NAT](02-pfsense/nat.md) · [Dépannage](02-pfsense/troubleshooting.md)

### 03 — MariaDB Galera

- [Concepts](03-galera/concepts.md) · [Installation](03-galera/installation.md) · [MYSQL-01](03-galera/mysql01.md) · [MYSQL-02](03-galera/mysql02.md) · [MYSQL-03](03-galera/mysql03.md) · [Bootstrap](03-galera/bootstrap.md) · [Reprise après panne](03-galera/recovery.md) · [Validation](03-galera/validation.md) · [Dépannage](03-galera/troubleshooting.md)

### 04 — HAProxy

- [Installation](04-haproxy/installation.md) · [Répartition SQL](04-haproxy/sql-load-balancing.md) · [Répartition WordPress](04-haproxy/wordpress-load-balancing.md) · [Publication GLPI](04-haproxy/glpi-proxy.md) · [Health-checks](04-haproxy/health-checks.md) · [Dépannage](04-haproxy/troubleshooting.md)

### 05 — WordPress

- [WEB-01](05-wordpress/web01.md) · [WEB-02](05-wordpress/web02.md) · [Apache](05-wordpress/apache.md) · [WordPress](05-wordpress/wordpress.md) · [Synchronisation](05-wordpress/synchronization.md) · [Base de données](05-wordpress/database.md) · [Failover](05-wordpress/failover.md) · [Dépannage](05-wordpress/troubleshooting.md)

### 06 — GLPI

- [Installation](06-glpi/installation.md) · [Apache](06-glpi/apache.md) · [Base de données](06-glpi/database.md) · [HAProxy](06-glpi/haproxy.md) · [Dépannage](06-glpi/troubleshooting.md)

### 07 — Sécurité

- [Segmentation réseau](07-security/network-segmentation.md) · [SSH](07-security/ssh.md) · [Gestion des secrets](07-security/secrets-management.md) · [Moindre privilège](07-security/least-privilege.md) · [Durcissement](07-security/hardening.md)

### 08 — Tests

- [Plan de tests](08-tests/test-plan.md) · [Tests Galera](08-tests/galera-tests.md) · [Tests HAProxy](08-tests/haproxy-tests.md) · [Failover WordPress](08-tests/wordpress-failover.md) · [Tests réseau](08-tests/network-tests.md) · [Matrice de validation](08-tests/validation-matrix.md)

### 09 — Dépannage

- [Incidents réels](09-troubleshooting/incidents.md) · [Méthodologie](09-troubleshooting/diagnostic-methodology.md) · [Galera](09-troubleshooting/galera.md) · [HAProxy](09-troubleshooting/haproxy.md) · [WordPress](09-troubleshooting/wordpress.md) · [Apache](09-troubleshooting/apache.md) · [SSH](09-troubleshooting/ssh.md) · [APT / dpkg](09-troubleshooting/apt-dpkg.md)

### 10 — Sauvegarde et restauration

- [Stratégie](10-backup-recovery/strategy.md) · [MariaDB](10-backup-recovery/mariadb.md) · [WordPress](10-backup-recovery/wordpress.md) · [GLPI](10-backup-recovery/glpi.md) · [Proxmox](10-backup-recovery/proxmox.md)

### 11 — BTS SIO

- [Compétences](11-bts-sio/skills.md) · [Présentation orale](11-bts-sio/oral-presentation.md) · [Questions du jury](11-bts-sio/jury-questions.md) · [Rétrospective](11-bts-sio/project-retrospective.md) · [Checklists avant publication](11-bts-sio/pre-publish-checklist.md)

### 12 — Gestion de projet

- [Workflow Git](12-project-management/git-workflow.md) · [Labels](12-project-management/labels.md) · [GitHub Project](12-project-management/github-project.md) · [Release v1.0.0](12-project-management/release-v1.0.0.md)
