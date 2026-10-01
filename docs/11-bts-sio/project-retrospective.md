# Rétrospective du projet

> Trame à compléter avec votre vécu réel. Les éléments techniques ci-dessous sont issus des incidents documentés ; les durées et ressentis sont à renseigner.

## Ce qui a fonctionné

- Construction **couche par couche** (réseau → bases → répartiteur → applications) : chaque étape validée avant la suivante.
- Scripts de contrôle (`check-galera.sh`, `check-wordpress.sh`) : diagnostic rapide et reproductible.
- En-tête `X-Served-By` : failover **visible** et démontrable en une commande.

## Difficultés rencontrées

| Difficulté | Ce qu'elle a appris | Incident |
|------------|---------------------|----------|
| Cluster `non-Primary` | Le quorum est une protection ; diagnostiquer avant de bootstrapper | INC-01 |
| `bind-address = 127.0.0.1` | Différence `refused` / `timed out` ; valeurs par défaut à vérifier | INC-02 |
| dpkg interrompu | Robustesse des sessions (`tmux`) | INC-03 |
| rsync absent | Dépendances implicites (SST, synchronisation) | INC-04 |
| 404 GLPI | Fonctionnement des réécritures Apache et du routeur GLPI | INC-05 |
| Clé SSH mal placée | Rôle exact des clés publique et privée | INC-06 |
| Empreinte d'hôte modifiée | Ne jamais ignorer un avertissement de sécurité sans vérifier | INC-07 |
| Compte `haproxy` | Séparer comptes humains et comptes de service | INC-08 |

## Si c'était à refaire

- Rédiger le **plan d'adressage et la matrice de flux** avant de créer la première VM.
- Créer les **règles pfSense deny-by-default dès le début**, plutôt que de restreindre à la fin (moins de surprises).
- Prendre un **snapshot Proxmox** systématique avant chaque étape.
- Archiver les **preuves** (captures, sorties) au fil de l'eau, pas à la fin.
- Versionner la documentation dès le premier jour.

## Indicateurs (à compléter)

| Indicateur | Valeur |
|------------|--------|
| Durée totale du projet | `<à compléter>` |
| Nombre de VM | 10 (9 Debian + pfSense) |
| Incidents documentés | 8 |
| Tests de la matrice validés avec preuve | `<x> / 20` |

## Compétences acquises

Voir [skills.md](skills.md). Points de progression personnels : `<à compléter>`.

## Suite

Roadmap : [README](../../README.md#roadmap) — issues suggérées : [github-project.md](../12-project-management/github-project.md).
