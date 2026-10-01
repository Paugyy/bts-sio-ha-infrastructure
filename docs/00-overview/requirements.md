# Prérequis

## Matériel (hôte Proxmox)

| Ressource | Minimum | Recommandé | Justification |
|-----------|---------|------------|---------------|
| CPU | 4 cœurs | 8 cœurs | 10 VM simultanées |
| RAM | 16 Go | 24 Go | Galera ~1 Go/nœud, pfSense 1 Go, web 1 Go |
| Disque | 150 Go | 250 Go SSD | Galera sensible à la latence disque |
| Réseau | 1 carte | 1 carte + bridge VLAN-aware | Trunk 802.1Q vers pfSense |

## Machines virtuelles

| VM | vCPU | RAM | Disque | OS | VLAN |
|----|------|-----|--------|----|------|
| pfSense | 1 | 1 Go | 16 Go | pfSense CE 2.7.x | WAN + trunk 301-304 |
| WEB-01 | 1 | 1 Go | 16 Go | Debian 12 | 301 |
| HAProxy | 1 | 1 Go | 10 Go | Debian 12 | 301 |
| GLPI-01 | 1 | 2 Go | 16 Go | Debian 12 | 301 |
| WEB-02 | 1 | 1 Go | 16 Go | Debian 12 | 301 |
| MYSQL-01 | 2 | 2 Go | 20 Go | Debian 12 | 302 |
| MYSQL-02 | 2 | 2 Go | 20 Go | Debian 12 | 302 |
| MYSQL-03 | 2 | 2 Go | 20 Go | Debian 12 | 302 |
| ADM-01 | 1 | 1 Go | 16 Go | Debian 12 | 303 |
| Guacamole | 2 | 2 Go | 16 Go | Debian 12 | 303 |

Ces valeurs sont des **recommandations de dimensionnement** pour un lab, pas une mesure.

## Logiciels

| Logiciel | Version | Source |
|----------|---------|--------|
| Proxmox VE | 8.x | proxmox.com |
| pfSense CE | 2.7.x | pfsense.org |
| Debian | 12 (Bookworm) | debian.org — installation minimale + SSH |
| MariaDB | 10.11 | Dépôt Debian (`mariadb-server`) |
| Galera | 4 | Dépôt Debian (`galera-4`) |
| HAProxy | 2.6 | Dépôt Debian (`haproxy`) |
| Apache / PHP | 2.4 / 8.2 | Dépôt Debian |
| WordPress | 6.x | wordpress.org |
| GLPI | 10.x | github.com/glpi-project/glpi/releases |

## Réseau

- Un réseau « WAN » de labo avec une IP libre pour pfSense (`10.4.0.198/24`, passerelle `10.4.0.254`).
- Un bridge Proxmox **VLAN aware** (ex. `vmbr1`) pour transporter les VLAN 301 à 304.
- Un accès aux dépôts Debian (via le NAT sortant de pfSense).

## Compétences attendues

- Installation de Debian et administration de base (systemd, apt, journalctl).
- Notions IP : masque, passerelle, routage, NAT.
- Notions SQL : création de base, d'utilisateur, `GRANT`.
- Utilisation de SSH et d'un éditeur en ligne de commande.

## Poste d'administration

| Outil | Usage |
|-------|-------|
| Client SSH (OpenSSH) | Administration des VM ([configs/ssh/](../../configs/ssh/linux-ssh-config.example)) |
| Navigateur | pfSense, WordPress, GLPI, statistiques HAProxy, générateur |
| Git | Cloner et mettre à jour ce dépôt |

Étape suivante : [deployment-order.md](deployment-order.md)
