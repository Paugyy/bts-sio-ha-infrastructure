# Compétences BTS SIO mobilisées

Correspondance entre le projet et les blocs de compétences du BTS SIO (référentiel 2020), option SISR.

> Intitulés repris du référentiel ; vérifier la formulation exacte avec la grille officielle de votre session avant de remplir le tableau de synthèse.

## Bloc 1 — Support et mise à disposition de services informatiques

| Compétence | Mise en œuvre dans le projet | Preuve |
|------------|------------------------------|--------|
| Gérer le patrimoine informatique | Inventaire des VM, plan d'adressage, GLPI déployé | [ip-addressing.md](../01-architecture/ip-addressing.md), GLPI |
| Répondre aux incidents et aux demandes d'assistance et d'évolution | Journal d'incidents structuré, méthodologie de diagnostic | [incidents.md](../09-troubleshooting/incidents.md) |
| Développer la présence en ligne de l'organisation | Site WordPress hautement disponible | [05-wordpress](../05-wordpress/wordpress.md) |
| Travailler en mode projet | Ordre de déploiement, roadmap, Git, issues, changelog | [deployment-order.md](../00-overview/deployment-order.md), [CHANGELOG](../../CHANGELOG.md) |
| Mettre à disposition des utilisateurs un service informatique | WordPress et GLPI publiés via HAProxy, tests de validation | [validation-matrix.md](../08-tests/validation-matrix.md) |
| Organiser son développement professionnel | Veille (Galera, HAProxy), documentation, portfolio | [project-retrospective.md](project-retrospective.md) |

## Bloc 2 SISR — Administration des systèmes et des réseaux

| Compétence | Mise en œuvre | Preuve |
|------------|---------------|--------|
| Concevoir une solution d'infrastructure réseau | Architecture VLAN, choix Galera/HAProxy, analyse des SPOF | [architecture-overview.md](../01-architecture/architecture-overview.md), [spof-analysis.md](../01-architecture/spof-analysis.md) |
| Installer, tester et déployer une solution d'infrastructure réseau | pfSense, Galera 3 nœuds, HAProxy, Apache, scripts d'installation | [configs/](../../configs/README.md), [scripts/install](../../scripts/README.md) |
| Exploiter, dépanner et superviser une solution d'infrastructure réseau | Scripts de contrôle, tests de failover, procédures de reprise Galera | [check-galera.sh](../../scripts/validation/check-galera.sh), [recovery.md](../03-galera/recovery.md) |

## Bloc 3 — Cybersécurité des services informatiques

| Compétence | Mise en œuvre | Preuve |
|------------|---------------|--------|
| Protéger les données à caractère personnel | Aucun secret ni donnée personnelle dans le dépôt, sauvegardes protégées | [SECURITY.md](../../SECURITY.md) |
| Préserver l'identité numérique de l'organisation | Pas d'exposition directe des serveurs ; seul HAProxy publié | [nat.md](../02-pfsense/nat.md) |
| Sécuriser les équipements et les usages des utilisateurs | VLAN utilisateurs restreint aux services publiés | [network-segmentation.md](../07-security/network-segmentation.md) |
| Garantir la disponibilité, l'intégrité et la confidentialité des services et des données | Redondance web et SQL, quorum, sauvegardes | [high-availability.md](../01-architecture/high-availability.md), [strategy.md](../10-backup-recovery/strategy.md) |
| Assurer la cybersécurité d'une infrastructure réseau, d'un système, d'un service | Deny-by-default, SSH par clé, moindre privilège, durcissement | [07-security](../07-security/hardening.md) |

## Savoir-faire techniques démontrables

- Configurer des VLAN 802.1Q (Proxmox + pfSense) et un routage inter-VLAN filtré.
- Mettre en place une redirection de port (DNAT) et justifier sa cible.
- Former, valider et **réparer** un cluster Galera (quorum, `grastate.dat`, bootstrap).
- Configurer HAProxy en couches 4 et 7 avec health-checks.
- Déployer une application PHP sur deux serveurs avec base partagée.
- Écrire des scripts Bash robustes (mode strict, simulation, idempotence).
- Versionner une infrastructure avec Git, CI et conventions de commits.
