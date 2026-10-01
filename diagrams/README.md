# Schémas

Schémas vectoriels (SVG) éditables avec un éditeur de texte ou Inkscape, affichés directement par GitHub. Fond blanc explicite pour rester lisibles en thème sombre.

| Schéma | Contenu | Utilisé dans |
|--------|---------|--------------|
| [architecture.svg](architecture.svg) | Vue d'ensemble : WAN, pfSense, 4 VLAN, toutes les VM et flux principaux | [README](../README.md), [architecture-overview.md](../docs/01-architecture/architecture-overview.md) |
| [vlans.svg](vlans.svg) | Trunk 802.1Q, bridge Proxmox, plan par VLAN | [vlan-design.md](../docs/01-architecture/vlan-design.md) |
| [wordpress-flow.svg](wordpress-flow.svg) | Requête WordPress de bout en bout (4 étapes) | [network-flows.md](../docs/01-architecture/network-flows.md) |
| [galera-flow.svg](galera-flow.svg) | Cycle d'une écriture Galera (diffusion, certification) | [concepts.md](../docs/03-galera/concepts.md) |
| [failover-web.svg](failover-web.svg) | Nominal → panne de WEB-01 → réintégration | [high-availability.md](../docs/01-architecture/high-availability.md), [failover.md](../docs/05-wordpress/failover.md) |
| [spof.svg](spof.svg) | Composants redondés et points uniques de défaillance | [spof-analysis.md](../docs/01-architecture/spof-analysis.md) |

## Conventions graphiques

| Couleur | Signification |
|---------|---------------|
| Bleu | VLAN 301 vWEB |
| Vert | VLAN 302 vBDD, Galera, composant redondé |
| Violet | VLAN 303 vADMIN |
| Ambre | VLAN 304 vUSER, redondance partielle |
| Rouge | pfSense, SPOF, composant en panne |
| Trait plein | Flux HTTP / réseau |
| Tirets verts | Flux SQL |

## Mise à jour

Toute modification d'adresse ou de composant doit être reportée dans les schémas **et** dans [ip-addressing.md](../docs/01-architecture/ip-addressing.md). Vérifier le rendu en ouvrant le fichier dans un navigateur.
