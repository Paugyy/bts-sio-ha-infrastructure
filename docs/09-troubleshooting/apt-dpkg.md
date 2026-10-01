# Dépannage — APT / dpkg

Incident réel : [INC-03](incidents.md#inc-03--dpkg-interrompu)

## dpkg interrompu

```text
E: dpkg was interrupted, you must manually run 'sudo dpkg --configure -a' to correct the problem.
```

```bash
# SUR LA VM CONCERNÉE
sudo dpkg --configure -a
sudo apt --fix-broken install -y
sudo apt update
```

## Verrou APT occupé

```text
E: Could not get lock /var/lib/dpkg/lock-frontend. It is held by process 1234 (apt)
```

| Étape | Commande |
|-------|----------|
| Identifier le processus | `ps -fp 1234` |
| S'il s'agit d'une installation légitime (unattended-upgrades) | **Attendre** sa fin |
| S'il est figé depuis longtemps | `sudo kill 1234`, puis `sudo dpkg --configure -a` |

Ne **jamais** supprimer les fichiers de verrou à la main pendant qu'un processus APT tourne : risque de corruption de la base dpkg.

## Dépendances cassées

```text
The following packages have unmet dependencies: ...
```

```bash
sudo apt --fix-broken install
sudo apt update && sudo apt full-upgrade
apt-cache policy <paquet>       # versions disponibles et dépôt d'origine
```

## Résolution DNS impossible

```text
Temporary failure resolving 'deb.debian.org'
```

```bash
cat /etc/resolv.conf            # nameserver = passerelle pfSense du VLAN ?
ping -c 2 10.0.X0.254
getent hosts deb.debian.org
```

Correction : règle pfSense DNS (53) et NAT sortant — voir [02-pfsense/troubleshooting.md](../02-pfsense/troubleshooting.md).

## Signatures / dépôts

```text
The following signatures couldn't be verified because the public key is not available
```

Cause habituelle : dépôt tiers ajouté sans sa clé. Dans ce projet, **seuls les dépôts Debian officiels** sont utilisés (MariaDB, Galera, HAProxy, Apache, PHP) : supprimer tout dépôt tiers non nécessaire dans `/etc/apt/sources.list.d/`.

## Prévention

- Lancer les installations longues dans `tmux` (`sudo apt install tmux`).
- Snapshot Proxmox avant une mise à jour majeure.
- `sudo apt update` avant chaque `apt install`.
