# pfSense — VLAN

## Création

**SUR PFSENSE** (*Interfaces → Assignments → VLANs → Add*)

| Parent | VLAN Tag | Priority | Description |
|--------|----------|----------|-------------|
| vtnet1 | 301 | 0 | vWEB |
| vtnet1 | 302 | 0 | vBDD |
| vtnet1 | 303 | 0 | vADMIN |
| vtnet1 | 304 | 0 | vUSER |

Les interfaces `vtnet1.301` à `vtnet1.304` apparaissent ensuite dans *Assignments* ([interfaces.md](interfaces.md)).

## Côté Proxmox

**SUR L'HÔTE PROXMOX**

1. *Datacenter → Node → System → Network → vmbr1* : cocher **VLAN aware**, appliquer.
2. Pour chaque VM Debian : *Hardware → Network Device → VLAN Tag* = 301, 302, 303 ou 304.
3. La carte `net1` de pfSense reste **sans tag** : elle reçoit toutes les trames étiquetées.

Alternative en ligne de commande :

```bash
# SUR L'HÔTE PROXMOX (exemple pour la VM 105 = MYSQL-01)
qm set 105 --net0 virtio,bridge=vmbr1,tag=302
```

## Pourquoi ça marche

```text
VM MYSQL-01 ──(trame non étiquetée)──► port vmbr1 tag 302 ──(étiquette 302)──► vtnet1 pfSense
                                                                                   │
                                                                         vtnet1.302 (10.0.20.254)
```

Proxmox ajoute l'étiquette 802.1Q en sortie de VM et la retire à l'entrée : la VM n'a besoin d'aucune configuration VLAN.

## Vérification

| Depuis | Commande | Attendu |
|--------|----------|---------|
| WEB-01 | `ping -c 2 10.0.10.254` | Réponse |
| MYSQL-01 | `ping -c 2 10.0.20.254` | Réponse |
| ADM-01 | `ping -c 2 10.0.30.254` | Réponse |
| WEB-01 | `ping -c 2 10.0.20.1` | Échec tant que la règle n'existe pas (attendu avec deny-by-default) |

Capture attendue : `evidence/screenshots/01-pfsense-vlans.png`
