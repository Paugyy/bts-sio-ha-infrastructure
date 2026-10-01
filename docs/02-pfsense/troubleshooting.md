# pfSense — Dépannage

## Une VM ne joint pas sa passerelle

| Élément | Contenu |
|---------|---------|
| **Symptôme** | `ping 10.0.X0.254` échoue depuis une VM |
| **Cause probable** | Mauvais tag VLAN sur la carte Proxmox, `vmbr1` non *VLAN aware*, interface pfSense non activée, mauvaise IP/masque dans la VM |
| **Diagnostic** | Comparer tag Proxmox, IP de la VM et interface pfSense |
| **Commandes** | `ip -4 addr` et `ip route` (VM) ; `qm config <vmid> \| grep net` (hôte Proxmox) ; *Status → Interfaces* (pfSense) |
| **Correction** | Corriger le tag (`qm set <vmid> --net0 virtio,bridge=vmbr1,tag=302`) ou l'adresse |
| **Validation** | `ping -c 2 10.0.X0.254` réussi |

## Un flux inter-VLAN est bloqué

| Élément | Contenu |
|---------|---------|
| **Symptôme** | `Connection timed out` entre deux VLAN (ex. HAProxy → MYSQL-01:3306) |
| **Cause probable** | Règle absente, mal placée (sous un *Block*) ou sur la mauvaise interface (doit être sur l'interface **source**) |
| **Diagnostic** | Journal pare-feu ; *Diagnostics → States* pendant le test |
| **Commandes** | **SUR HAPROXY** `nc -zv -w 3 10.0.20.1 3306` ; **SUR PFSENSE** *Status → System Logs → Firewall* |
| **Correction** | Ajouter / déplacer la règle *Pass* sur l'interface vWEB |
| **Validation** | `nc -zv 10.0.20.1 3306` → `succeeded` |

> `Connection refused` (refus immédiat) ≠ `timed out` (silence). Un refus signifie que le paquet **est arrivé** mais que rien n'écoute : le problème est sur le serveur (service arrêté, `bind-address`), pas sur pfSense.

## Le NAT ne fonctionne pas

| Élément | Contenu |
|---------|---------|
| **Symptôme** | `http://10.4.0.198:8081` ne répond pas depuis le réseau labo |
| **Cause probable** | *Block private networks* coché sur le WAN ; règle WAN associée absente ; HAProxy arrêté |
| **Diagnostic** | Tester d'abord HAProxy de l'intérieur, puis le NAT |
| **Commandes** | **SUR ADM-01** `curl -I http://10.0.10.2` ; **SUR PFSENSE** *Interfaces → WAN* et *Firewall → Rules → WAN* |
| **Correction** | Décocher *Block private networks and loopback addresses* ; recréer la règle associée |
| **Validation** | `curl -I http://10.4.0.198:8081` → `HTTP/1.1 200` ou `30x` |

## Perte d'accès à l'interface web

| Élément | Contenu |
|---------|---------|
| **Symptôme** | `https://10.0.30.254` inaccessible après modification des règles |
| **Cause probable** | Règle d'administration supprimée, anti-lockout désactivé |
| **Diagnostic** | Console Proxmox de la VM pfSense |
| **Commandes** | Console : option *8) Shell*, puis `pfctl -d` (désactive le filtrage **temporairement**) |
| **Correction** | Recréer la règle vADMIN → 443, puis `pfctl -e` |
| **Validation** | Accès web rétabli avec filtrage actif |

## Les VM n'accèdent pas aux dépôts Debian

| Élément | Contenu |
|---------|---------|
| **Symptôme** | `apt update` : `Temporary failure resolving 'deb.debian.org'` |
| **Cause probable** | Règle DNS absente, NAT sortant désactivé, résolveur pfSense non configuré |
| **Commandes** | `cat /etc/resolv.conf` ; `ping -c 2 10.0.X0.254` ; `getent hosts deb.debian.org` |
| **Correction** | Autoriser 53 vers l'adresse pfSense du VLAN ; `nameserver 10.0.X0.254` dans la VM |
| **Validation** | `sudo apt update` sans erreur |
