# pfSense — Installation

## VM Proxmox

**SUR L'HÔTE PROXMOX** (interface web)

| Paramètre | Valeur |
|-----------|--------|
| Nom | `pfSense` |
| ISO | pfSense CE 2.7.x (amd64) |
| CPU / RAM / disque | 1 vCPU / 1 Go / 16 Go |
| net0 | `vmbr0` (WAN), modèle VirtIO |
| net1 | `vmbr1` (interne, VLAN aware), **sans tag** — reçoit le trunk |

## Installation

1. Démarrer sur l'ISO, accepter la licence, choisir **Install**.
2. Partitionnement : **Auto (ZFS)** ou **Auto (UFS)** — UFS suffit pour un lab.
3. Redémarrer en retirant l'ISO.

## Assignation initiale (console)

**SUR PFSENSE** (console Proxmox)

```text
Should VLANs be set up now? → n       (les VLAN seront créés depuis l'interface web)
Enter the WAN interface name → vtnet0
Enter the LAN interface name → vtnet1
```

Puis, option **2) Set interface(s) IP address** :

| Interface | IP | Passerelle | DHCP |
|-----------|----|------------|------|
| WAN (vtnet0) | 10.4.0.198/24 | 10.4.0.254 | Non |
| LAN (vtnet1) | IP temporaire (ex. 10.0.30.254/24) | — | Non |

L'interface LAN temporaire sert uniquement à accéder à l'interface web pendant la configuration ; elle sera remplacée par les VLAN.

## Assistant web

**SUR ADM-01** (navigateur) : `https://10.0.30.254/` — identifiants par défaut à **changer immédiatement**.

| Étape | Valeur |
|-------|--------|
| Hostname / Domain | `pfsense` / `lab.local` |
| DNS | Résolveur du labo ou `10.4.0.254` |
| Fuseau horaire | Europe/Paris |
| WAN | Statique 10.4.0.198/24, passerelle 10.4.0.254 |
| **Block private networks** (WAN) | **Décoché** : le WAN du labo est en 10.4.0.0/24 (privé) |
| Mot de passe admin | `<PASSWORD>` (gestionnaire de mots de passe) |

## Vérification

**SUR PFSENSE** (*Diagnostics → Ping*)

- Ping `10.4.0.254` depuis WAN : réussi.
- Ping `deb.debian.org` : réussi (DNS et sortie fonctionnels).

Étapes suivantes : [interfaces.md](interfaces.md) puis [vlans.md](vlans.md)
