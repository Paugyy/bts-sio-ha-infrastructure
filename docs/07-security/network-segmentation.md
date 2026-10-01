# Sécurité — Segmentation réseau

## Objectif

Limiter la **propagation** d'une compromission : un attaquant qui prend le contrôle d'un serveur web ne doit pas pouvoir atteindre librement les bases de données, l'administration ou les postes.

## Zones et niveaux de confiance

```text
   Confiance faible                                         Confiance élevée
   ─────────────────────────────────────────────────────────────────────────►
   WAN (labo)   vUSER (304)    vWEB (301)            vBDD (302)   vADMIN (303)
                 postes        HAProxy, WEB, GLPI      Galera       ADM-01, Guacamole
```

| De \ Vers | vWEB | vBDD | vADMIN | vUSER | WAN |
|-----------|------|------|--------|-------|-----|
| **WAN** | HAProxy:80 via NAT 8081 | ✗ | ✗ | ✗ | — |
| **vUSER** | HAProxy:80, 8080 | ✗ | ✗ | — | 80, 443 |
| **vWEB** | (intra-VLAN) | HAProxy → 3306 | ✗ | ✗ | 80, 443 (apt) |
| **vBDD** | ✗ | (intra-VLAN) | ✗ | ✗ | 80, 443 (apt) |
| **vADMIN** | 22, 80, 3306, 8080, 8404 | 22 | (intra-VLAN) | ✗ | 80, 443 |

✗ = bloqué par la politique deny-by-default.

## Défense en profondeur

La segmentation n'est qu'**une** couche :

| Couche | Mesure | Document |
|--------|--------|----------|
| Réseau | VLAN + filtrage pfSense | [firewall-rules.md](../../configs/pfsense/firewall-rules.md) |
| Hôte | Pare-feu local (nftables), services en écoute sur la bonne IP | [hardening.md](hardening.md) |
| Accès | SSH par clé, pas de root, bastion | [ssh.md](ssh.md) |
| Application | Comptes SQL dédiés, privilèges limités | [least-privilege.md](least-privilege.md) |
| Données | Secrets hors dépôt, sauvegardes | [secrets-management.md](secrets-management.md) |

## Limite : le trafic intra-VLAN

pfSense ne voit pas le trafic à l'intérieur d'un VLAN. Dans vWEB, WEB-01 peut joindre GLPI-01:80 ou HAProxy:8404 sans contrôle. Compensations :

- `bind-address` / écoute sur des IP précises ;
- ACL HAProxy (la page de stats n'accepte que 10.0.30.0/24) ;
- pare-feu local sur chaque VM ([hardening.md](hardening.md)).

## Vérification

Les flux interdits se testent autant que les flux autorisés : [08-tests/network-tests.md](../08-tests/network-tests.md).
