# Vue d'ensemble de l'architecture

<p align="center"><img src="../../diagrams/architecture.svg" alt="Schéma d'architecture" width="850"></p>

## Couches

| Couche | Composants | Rôle | Redondance |
|--------|------------|------|------------|
| Périmètre | pfSense | Routage inter-VLAN, NAT, filtrage | Non (SPOF) |
| Répartition | HAProxy 10.0.10.2 | Point d'entrée unique HTTP et SQL | Non (SPOF) |
| Application | WEB-01, WEB-02 | WordPress | Oui (2 nœuds actifs) |
| Application | GLPI-01 | ITSM | Non (SPOF assumé) |
| Données | MYSQL-01/02/03 | MariaDB Galera | Oui (3 nœuds, quorum) |
| Administration | ADM-01, Guacamole | Bastion, accès distant | Non (hors chemin du service) |

## Principes de conception

1. **Un seul point d'entrée par service** : les clients et les applications ne connaissent que `10.0.10.2`. Les serveurs réels peuvent tomber, être remplacés ou ajoutés sans modifier les clients.
2. **Les applications ne parlent jamais directement à un nœud SQL** : `DB_HOST = 10.0.10.2:3306`. Si un nœud tombe, HAProxy l'écarte.
3. **Nombre impair de nœuds de base** : 3 nœuds permettent de garder une majorité (2/3) après une panne.
4. **Séparation des rôles par VLAN** : les serveurs web, les bases, l'administration et les utilisateurs sont isolés ; pfSense contrôle chaque flux entre eux.
5. **Health-checks partout** : HAProxy vérifie en continu WordPress (HTTP), GLPI (HTTP) et MariaDB (protocole MySQL).

## Chemins des requêtes

### Visiteur WordPress

```text
Client ─► pfSense WAN:8081 ─(DNAT)─► HAProxy :80 ─► WEB-01 ou WEB-02 :80
                                                       │
                                                       └─► HAProxy :3306 ─► MYSQL-01/02/03
```

### Utilisateur GLPI (VLAN vUSER)

```text
Poste 10.0.40.x ─► pfSense (règle vUSER) ─► HAProxy :8080 ─► GLPI-01 :80 ─► HAProxy :3306 ─► Galera
```

### Administrateur

```text
ADM-01 10.0.30.1 ─► pfSense (règle vADMIN) ─► SSH :22 vers vWEB / vBDD
```

Détail de tous les flux : [network-flows.md](network-flows.md)

## Documents liés

- [network-topology.md](network-topology.md) — topologie physique et logique
- [ip-addressing.md](ip-addressing.md) — plan d'adressage complet
- [vlan-design.md](vlan-design.md) — justification des VLAN
- [high-availability.md](high-availability.md) — mécanismes de HA
- [spof-analysis.md](spof-analysis.md) — points uniques de défaillance
