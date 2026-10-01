# Plan d'adressage

## Réseaux

| Réseau | VLAN | Nom | CIDR | Passerelle | Plage utilisée | Usage |
|--------|------|-----|------|------------|----------------|-------|
| WAN | — | WAN | 10.4.0.0/24 | 10.4.0.254 | 10.4.0.198 | Réseau du laboratoire |
| Web | 301 | vWEB | 10.0.10.0/24 | 10.0.10.254 | .1 à .4 | Serveurs exposés via HAProxy |
| Bases | 302 | vBDD | 10.0.20.0/24 | 10.0.20.254 | .1 à .3 | Cluster Galera |
| Admin | 303 | vADMIN | 10.0.30.0/24 | 10.0.30.254 | .1 à .2 | Administration |
| Utilisateurs | 304 | vUSER | 10.0.40.0/24 | 10.0.40.254 | DHCP (exemple : .100 à .199) | Postes clients |

Convention : la passerelle est toujours en **.254** ; les serveurs en adresses basses, statiques.

## Hôtes

| VM | IP | Masque | Passerelle | VLAN | OS | Services | Ports en écoute |
|----|----|--------|------------|------|----|----------|-----------------|
| pfSense (WAN) | 10.4.0.198 | /24 | 10.4.0.254 | — | pfSense CE | Pare-feu, NAT | 8081 (NAT) |
| WEB-01 | 10.0.10.1 | /24 | 10.0.10.254 | 301 | Debian 12 | Apache, PHP, WordPress | 22, 80 |
| HAProxy | 10.0.10.2 | /24 | 10.0.10.254 | 301 | Debian 12 | HAProxy | 22, 80, 3306, 8080, 8404 |
| GLPI-01 | 10.0.10.3 | /24 | 10.0.10.254 | 301 | Debian 12 | Apache, PHP, GLPI | 22, 80 |
| WEB-02 | 10.0.10.4 | /24 | 10.0.10.254 | 301 | Debian 12 | Apache, PHP, WordPress | 22, 80 |
| MYSQL-01 | 10.0.20.1 | /24 | 10.0.20.254 | 302 | Debian 12 | MariaDB 10.11, Galera 4 | 22, 3306, 4444, 4567, 4568 |
| MYSQL-02 | 10.0.20.2 | /24 | 10.0.20.254 | 302 | Debian 12 | MariaDB 10.11, Galera 4 | 22, 3306, 4444, 4567, 4568 |
| MYSQL-03 | 10.0.20.3 | /24 | 10.0.20.254 | 302 | Debian 12 | MariaDB 10.11, Galera 4 | 22, 3306, 4444, 4567, 4568 |
| ADM-01 | 10.0.30.1 | /24 | 10.0.30.254 | 303 | Debian 12 | SSH, outils | 22 |
| Guacamole | 10.0.30.2 | /24 | 10.0.30.254 | 303 | Debian 12 | Apache Guacamole | 22, 8080 (exemple) |

## Points d'accès des services

| Service | URL / adresse | Depuis |
|---------|---------------|--------|
| WordPress (interne) | `http://10.0.10.2/` | vUSER, vADMIN |
| WordPress (réseau labo) | `http://10.4.0.198:8081/` | WAN |
| GLPI | `http://10.0.10.2:8080/` | vUSER, vADMIN |
| SQL (applications) | `10.0.10.2:3306` | WEB-01, WEB-02, GLPI-01 |
| Statistiques HAProxy | `http://10.0.10.2:8404/stats` | vADMIN uniquement |
| pfSense | `https://10.0.30.254/` | vADMIN |

## Ports Galera

| Port | Proto | Usage | Entre |
|------|-------|-------|-------|
| 3306 | TCP | Clients SQL | HAProxy → nœuds |
| 4567 | TCP (+UDP multicast si activé) | Réplication de groupe | Nœud ↔ nœud |
| 4568 | TCP | IST (transfert incrémental) | Nœud ↔ nœud |
| 4444 | TCP | SST (transfert complet, rsync) | Nœud ↔ nœud |

Ce plan est également disponible au format JSON dans [generator/examples/reference-infrastructure.json](../../generator/examples/reference-infrastructure.json).
