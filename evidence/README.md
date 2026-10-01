# Preuves de tests

Ce dossier contient les **preuves réelles** des tests de la [matrice de validation](../docs/08-tests/validation-matrix.md) : captures d'écran et sorties de commandes.

> **Règle** : aucune preuve n'est fabriquée, retouchée ou générée. Une capture absente signifie un test non prouvé ; son statut reste « Déclaré » ou « À exécuter » dans la matrice.

## Arborescence

```text
evidence/
├── screenshots/     captures d'écran (.png)
└── test-results/    sorties de commandes et journaux de tests (.txt, .log)
```

## Captures attendues

| Fichier | Contenu | Test |
|---------|---------|------|
| `01-pfsense-vlans.png` | *Interfaces → Assignments → VLANs* : 301 à 304 | T01 |
| `02-pfsense-firewall-vweb.png` | *Firewall → Rules → vWEB* | T19 |
| `03-galera-cluster-size.png` | `wsrep_cluster_size = 3`, `Primary` | T04, T05 |
| `04-galera-synced.png` | `Synced`, `wsrep_ready = ON` | T06, T07 |
| `05-haproxy-status.png` | Page `http://10.0.10.2:8404/stats`, tous les serveurs UP | T13 |
| `06-wordpress-web01.png` | Site servi par WEB-01 (`X-Served-By`) | T11 |
| `07-wordpress-web02.png` | Site servi par WEB-02 | T12 |
| `08-failover-web01-down.png` | WEB-01 DOWN dans les stats, site toujours servi par WEB-02 | T14 |
| `09-failover-web02-down.png` | WEB-02 DOWN, site servi par WEB-01 | T15 |
| `10-glpi.png` | GLPI via `http://10.0.10.2:8080` | T17 |

## Convention de nommage

### Captures

```text
NN-composant-description.png
```

- `NN` : numéro à deux chiffres (ordre de la soutenance) ;
- minuscules, mots séparés par des tirets, sans accents ni espaces ;
- PNG de préférence (lisible, sans perte).

### Sorties de commandes

```text
AAAA-MM-JJ-TNN-description.txt
```

Exemple : `2026-10-01-T10-sql-round-robin.txt`. Les scripts de failover produisent automatiquement `AAAAMMJJ-HHMMSS-failover-web01.log` avec l'option `--save`.

```bash
# SUR LA VM CONCERNÉE — sortie sans codes couleur
NO_COLOR=1 ./scripts/validation/check-galera.sh | tee "evidence/test-results/$(date +%F)-T04-T07-$(hostname -s).txt"
```

## Anonymisation (obligatoire avant commit)

- [ ] Aucun mot de passe visible (champ de saisie, fichier ouvert, historique du terminal)
- [ ] Aucun cookie, jeton ou clé visible (outils de développement, barre d'adresse)
- [ ] Aucune IP publique ni nom personnel dans la barre de titre ou l'invite du shell
- [ ] Notifications et onglets sans rapport fermés

Les adresses privées du lab (`10.x`) peuvent rester visibles : elles sont documentées publiquement.
