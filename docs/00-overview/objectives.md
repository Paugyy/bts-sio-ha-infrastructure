# Objectifs

## Objectifs techniques

| # | Objectif | Critère de réussite mesurable | Test |
|---|----------|-------------------------------|------|
| O1 | Segmenter le réseau | 4 VLAN, chaque VM dans le bon VLAN, routage via pfSense | T01, T19 |
| O2 | Base de données répliquée | `wsrep_cluster_size = 3`, `Primary`, `Synced` sur les 3 nœuds | T04 à T08 |
| O3 | Tolérance à la panne d'un nœud SQL | Arrêt d'un nœud : cluster `Primary` avec 2 nœuds, SQL toujours disponible | T20 |
| O4 | Point d'accès SQL unique | Les applications utilisent `10.0.10.2:3306`, réparti sur 3 nœuds | T09, T10 |
| O5 | Couche web redondée | WEB-01 et WEB-02 servent le même site via `10.0.10.2:80` | T11 à T13 |
| O6 | Tolérance à la panne d'un serveur web | Arrêt d'Apache sur l'un : aucune erreur client | T14, T15 |
| O7 | Réintégration automatique | Serveur relancé : remis en service sans action sur HAProxy | T16 |
| O8 | GLPI opérationnel | GLPI accessible via `10.0.10.2:8080`, base sur Galera | T17 |
| O9 | Publication maîtrisée | Seul HAProxy est publié (NAT `WAN:8081`) | T18 |
| O10 | Filtrage | Les VLAN n'accèdent qu'aux flux autorisés | T19 |

## Objectifs de documentation

- Un tiers peut **reconstruire** le lab avec [deployment-order.md](deployment-order.md).
- Chaque commande indique **la VM** sur laquelle elle s'exécute.
- Chaque incident rencontré est **documenté** (symptôme, cause, correction, validation).
- Les **limites** et **SPOF** sont identifiés, pas cachés.

## Objectifs pédagogiques (BTS SIO)

- Expliquer la différence entre **haute disponibilité**, **répartition de charge** et **sauvegarde**.
- Expliquer le **quorum** et justifier le nombre impair de nœuds.
- Justifier chaque **règle de filtrage**.
- Démontrer un **failover** en direct devant un jury.

Correspondance avec le référentiel : [11-bts-sio/skills.md](../11-bts-sio/skills.md)
