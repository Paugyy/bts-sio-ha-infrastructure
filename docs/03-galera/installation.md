# Galera — Installation

Procédure commune aux trois nœuds. Les valeurs spécifiques sont dans [mysql01.md](mysql01.md), [mysql02.md](mysql02.md) et [mysql03.md](mysql03.md).

## 1. Prérequis

**SUR MYSQL-01, MYSQL-02 et MYSQL-03**

```bash
ip -4 addr show                 # IP correcte (10.0.20.X)
ping -c 2 10.0.20.254           # passerelle
ping -c 2 10.0.20.1             # voisins (même VLAN)
sudo apt update                 # accès aux dépôts
timedatectl                     # horloge synchronisée (NTP)
```

## 2. Paquets

**SUR CHAQUE NŒUD**

```bash
sudo apt install -y mariadb-server mariadb-client galera-4 rsync
mariadb --version               # 10.11.x attendu
```

> `rsync` est indispensable à la méthode SST `rsync` : sans lui, un nœud ne peut pas rejoindre le cluster (incident [INC-04](../09-troubleshooting/incidents.md#inc-04--rsync-absent)).

Alternative scriptée (simulation puis exécution) :

```bash
sudo ./scripts/install/install-galera.sh --node-name MYSQL-01 --node-ip 10.0.20.1
sudo ./scripts/install/install-galera.sh --node-name MYSQL-01 --node-ip 10.0.20.1 --apply
```

## 3. Sécurisation initiale

**SUR CHAQUE NŒUD** (avant formation du cluster)

```bash
sudo mariadb-secure-installation
```

| Question | Réponse |
|----------|---------|
| Switch to unix_socket authentication | `n` (déjà actif sous Debian) |
| Change the root password | `n` (root via `sudo mariadb` uniquement) |
| Remove anonymous users | `Y` |
| Disallow root login remotely | `Y` |
| Remove test database | `Y` |
| Reload privilege tables | `Y` |

## 4. Configuration

**SUR CHAQUE NŒUD** : copier les deux fichiers de [configs/galera/](../../configs/galera/README.md) correspondant au nœud.

```bash
# Exemple SUR MYSQL-01
sudo cp /etc/mysql/mariadb.conf.d/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf.orig
sudo cp configs/galera/mysql01/50-server.cnf.example /etc/mysql/mariadb.conf.d/50-server.cnf
sudo cp configs/galera/mysql01/60-galera.cnf.example /etc/mysql/mariadb.conf.d/60-galera.cnf
```

Contrôle :

```bash
grep -E '^(bind-address|wsrep_)' /etc/mysql/mariadb.conf.d/50-server.cnf /etc/mysql/mariadb.conf.d/60-galera.cnf
```

## 5. Arrêt avant formation du cluster

**SUR LES 3 NŒUDS**

```bash
sudo systemctl stop mariadb
```

Le cluster se forme ensuite selon [bootstrap.md](bootstrap.md) : **un seul** nœud est bootstrappé.

## 6. Pare-feu local (optionnel, recommandé)

Voir [07-security/hardening.md](../07-security/hardening.md#nftables-sur-les-nœuds-galera) pour limiter 4567/4568/4444 aux deux autres nœuds et 3306 à HAProxy.
