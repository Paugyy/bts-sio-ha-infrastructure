# pfSense — Règles de filtrage

Les règles détaillées, interface par interface, sont dans [configs/pfsense/firewall-rules.md](../../configs/pfsense/firewall-rules.md). Cette page explique **la méthode**.

## Principes

1. **Deny-by-default** : sur une interface pfSense sans règle, tout trafic entrant est bloqué. On n'ajoute que des règles *Pass* ciblées.
2. **Filtrage à l'entrée** : une règle sur l'interface vWEB s'applique aux paquets **émis par** le VLAN vWEB.
3. **Première correspondance** : les règles sont lues de haut en bas ; la première qui correspond décide.
4. **Stateful** : le trafic de retour d'une connexion autorisée est accepté automatiquement — inutile de créer une règle « retour ».
5. **Alias** : les groupes d'IP et de ports sont nommés (`GALERA_NODES`, `WEB_PORTS`) pour des règles lisibles et maintenables.

## Démarche de construction

1. Lister les flux nécessaires : [network-flows.md](../01-architecture/network-flows.md).
2. Créer les alias (*Firewall → Aliases*).
3. Pour chaque interface, ajouter les règles *Pass* du plus spécifique au plus général.
4. Ajouter un *Block* explicite vers `RFC1918` **avant** la règle d'accès Internet (sinon « any » autoriserait aussi les autres VLAN).
5. Activer la journalisation (*Log*) sur les règles de blocage explicites pour le diagnostic.
6. **Tester** les flux autorisés **et** les flux interdits ([network-tests.md](../08-tests/network-tests.md)).

## Exemple : règle HAProxy → Galera

**SUR PFSENSE** (*Firewall → Rules → vWEB → Add*)

| Champ | Valeur |
|-------|--------|
| Action | Pass |
| Interface | vWEB |
| Protocol | TCP |
| Source | Single host or alias : `HAPROXY` |
| Destination | Single host or alias : `GALERA_NODES` |
| Destination port | 3306 |
| Description | HAProxy vers Galera (SQL) |

Seul HAProxy peut joindre les bases : un serveur web compromis ne peut pas ouvrir de connexion directe vers MYSQL-01.

## Pourquoi deny-by-default ?

- Un oubli se traduit par un **service bloqué** (visible, corrigeable) plutôt que par une **ouverture non voulue** (invisible, exploitable).
- La liste des règles devient la **documentation exacte** des flux autorisés.
- C'est l'application du principe de **moindre privilège** au réseau.

## Journal

*Status → System Logs → Firewall* : chaque paquet bloqué par une règle journalisée apparaît avec source, destination et port — premier réflexe en cas de « ça ne passe pas ».

Capture attendue : `evidence/screenshots/02-pfsense-firewall-vweb.png`
