# Plan de tests

## Objectif

Démontrer, par des tests **reproductibles** et **tracés**, que l'infrastructure atteint ses objectifs ([objectives.md](../00-overview/objectives.md)) : fonctionnement nominal, tolérance aux pannes, filtrage.

## Organisation

| Famille | Tests | Document | Outils |
|---------|-------|----------|--------|
| Réseau | T01, T02, T18, T19 | [network-tests.md](network-tests.md) | `check-network.sh`, `nc`, `curl` |
| Base de données | T03 à T08, T20 | [galera-tests.md](galera-tests.md) | `check-galera.sh`, `test-galera-node.sh` |
| Répartition | T09, T10, T13 | [haproxy-tests.md](haproxy-tests.md) | `check-haproxy.sh`, `test-sql-round-robin.sh` |
| Web | T11, T12, T14 à T16 | [wordpress-failover.md](wordpress-failover.md) | `check-wordpress.sh`, `test-web0X-failure.sh` |
| GLPI | T17 | [haproxy-tests.md](haproxy-tests.md) | `check-glpi.sh` |

Synthèse et statuts : [validation-matrix.md](validation-matrix.md)

## Ordre d'exécution

```text
T01-T02 (réseau, SSH)
   └─► T03-T08 (MariaDB, Galera)
         └─► T09-T10 (HAProxy SQL)
               └─► T11-T13 (WordPress, HAProxy HTTP)
                     └─► T17 (GLPI) ─► T18-T19 (NAT, firewall)
                           └─► T14-T16, T20 (pannes : en dernier, sur une base saine)
```

Les tests de panne ne sont lancés que lorsque **tous** les tests nominaux sont réussis : sinon, impossible de savoir si un échec vient de la panne simulée ou d'un défaut préexistant.

## Règles

1. **Une preuve par test** : sortie de commande (fichier texte) ou capture d'écran, rangée dans [evidence/](../../evidence/README.md).
2. **Statut honnête** : un test non rejoué depuis la dernière modification repasse en « À rejouer ».
3. **Date et version** : chaque campagne note la date et le commit du dépôt.
4. **Pannes réversibles** : les pannes sont simulées par arrêt de service (`systemctl stop`), jamais par suppression de données.
5. **Snapshot préalable** : avant une campagne de pannes, snapshot Proxmox des VM concernées.

## Enregistrer une campagne

```bash
# SUR ADM-01 — exemple d'archivage d'une sortie
./scripts/validation/check-wordpress.sh | tee "evidence/test-results/$(date +%F)-T13-haproxy-http.txt"

# Les scripts de failover ont une option dédiée
./scripts/failover/test-web01-failure.sh --save
```

Pour supprimer les codes couleur dans les fichiers : `NO_COLOR=1 ./scripts/...`

## Critères de réussite globaux

| Critère | Seuil |
|---------|-------|
| Tests nominaux (T01 à T13, T17 à T19) | 100 % réussis |
| Tests de panne (T14 à T16, T20) | 100 % réussis, 0 erreur client pendant la panne web |
| Délai de détection d'une panne web | ≤ 10 s (`fall 3` × `inter 3s`) |
| Délai de réintégration | ≤ 10 s (`rise 2` × `inter 3s`) |
