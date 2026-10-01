# Topologie réseau

## Topologie physique (Proxmox)

```text
           Réseau labo 10.4.0.0/24 (passerelle 10.4.0.254)
                           │
                    ┌──────┴──────┐  vmbr0 (bridge WAN)
                    │  Hôte       │
                    │  Proxmox VE │  vmbr1 (bridge interne, VLAN aware, aucun IP)
                    └──────┬──────┘
                           │
       ┌───────────────────┼─────────────────────────────────────┐
       │                   │                                     │
  pfSense net0 (vmbr0)   pfSense net1 (vmbr1, trunk 301-304)   VM Debian (vmbr1, tag = VLAN)
```

| VM | Interface Proxmox | Bridge | Tag VLAN |
|----|-------------------|--------|----------|
| pfSense | net0 | vmbr0 | — (WAN) |
| pfSense | net1 | vmbr1 | aucun (trunk : reçoit les 4 VLAN étiquetés) |
| WEB-01, HAProxy, GLPI-01, WEB-02 | net0 | vmbr1 | 301 |
| MYSQL-01, MYSQL-02, MYSQL-03 | net0 | vmbr1 | 302 |
| ADM-01, Guacamole | net0 | vmbr1 | 303 |
| Postes utilisateurs | net0 | vmbr1 | 304 |

Côté Proxmox, le tag est posé **sur la carte réseau de la VM** (*Hardware → Network Device → VLAN Tag*). La VM Debian ne voit donc qu'un réseau classique, sans configuration VLAN dans l'OS.

## Topologie logique

```text
                         ┌───────────────────────────┐
             WAN ────────┤ pfSense                   │
         10.4.0.198/24   │  vtnet1.301  10.0.10.254  ├──── vWEB   10.0.10.0/24
                         │  vtnet1.302  10.0.20.254  ├──── vBDD   10.0.20.0/24
                         │  vtnet1.303  10.0.30.254  ├──── vADMIN 10.0.30.0/24
                         │  vtnet1.304  10.0.40.254  ├──── vUSER  10.0.40.0/24
                         └───────────────────────────┘
```

pfSense est le **routeur unique** entre les VLAN (« router on a stick ») : tout flux inter-VLAN passe par lui et est donc soumis à ses règles.

## Configuration réseau d'une VM Debian

**SUR MYSQL-02** (exemple)

```bash
sudo nano /etc/network/interfaces
```

```text
auto ens18
iface ens18 inet static
    address 10.0.20.2/24
    gateway 10.0.20.254
```

```bash
sudo systemctl restart networking
ip -4 addr show ens18
ip route
ping -c 2 10.0.20.254
```

> Le nom de l'interface (`ens18`) dépend de la VM : le vérifier avec `ip link`.

Schéma VLAN : [diagrams/vlans.svg](../../diagrams/vlans.svg)
