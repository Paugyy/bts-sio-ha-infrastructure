# Contexte du projet

## Cadre

Projet réalisé dans le cadre du **BTS Services Informatiques aux Organisations, option SISR** (Solutions d'Infrastructure, Systèmes et Réseaux). Il s'appuie sur un hyperviseur **Proxmox VE** mis à disposition en laboratoire, raccordé à un réseau de travaux pratiques (`10.4.0.0/24`).

## Situation de départ

Une organisation fictive héberge :

- un **site vitrine WordPress** consulté par ses clients ;
- un outil de **gestion de parc et d'assistance GLPI** utilisé en interne.

Dans une installation classique, chaque application repose sur **un serveur web et une base de données uniques** :

```text
Client ──► Serveur web ──► Base de données
             (SPOF)            (SPOF)
```

La moindre panne (mise à jour ratée, disque plein, redémarrage, crash) rend le service indisponible.

## Besoin exprimé

| Besoin | Traduction technique |
|--------|----------------------|
| Le site doit rester accessible si un serveur tombe | Deux serveurs web + répartiteur de charge avec health-checks |
| Les données ne doivent pas dépendre d'un seul serveur | Cluster de bases de données répliqué de manière synchrone |
| Les serveurs ne doivent pas être exposés directement | Segmentation VLAN + pare-feu deny-by-default + NAT vers le seul répartiteur |
| L'administration doit être maîtrisée | VLAN d'administration dédié, SSH par clé, bastion |
| L'infrastructure doit pouvoir être reconstruite | Documentation, configurations versionnées, scripts |

## Périmètre

**Inclus** : réseau (pfSense, VLAN), cluster Galera 3 nœuds, HAProxy (HTTP + SQL), 2 serveurs WordPress, GLPI, sécurisation de base, tests de bascule, documentation.

**Exclus de la v1.0.0** (voir [roadmap](../../README.md#roadmap)) : redondance du répartiteur et du pare-feu, HTTPS, supervision, sauvegardes automatisées, stockage partagé.

## Contraintes

- **Un seul hyperviseur** : la redondance est logique (VM), pas physique.
- **Ressources limitées** : 9 VM Linux + pfSense sur un même hôte.
- **Réseau de labo** : le « WAN » est un réseau privé, pas Internet.
- **Projet pédagogique** : les choix privilégient la compréhension (round-robin SQL visible, en-tête `X-Served-By`) plutôt que l'optimisation de production. Les écarts avec une production sont signalés.

## Livrables

| Livrable | Emplacement |
|----------|-------------|
| Dépôt documenté | Ce dépôt |
| Configurations | [configs/](../../configs/README.md) |
| Scripts de validation | [scripts/](../../scripts/README.md) |
| Générateur HTML | [generator/](../../generator/README.md) |
| Preuves de tests | [evidence/](../../evidence/README.md) |
| Supports de soutenance | [deliverables/](../../deliverables/README.md) |
