# Règles de filtrage pfSense

Politique : **deny-by-default**. pfSense bloque implicitement tout ce qui n'est pas autorisé sur une interface interne ; chaque flux nécessaire est ouvert explicitement, au plus près (source, destination, port).

Rappels :

- Les règles s'appliquent **à l'entrée** de l'interface (trafic émis par le VLAN).
- Elles sont évaluées **de haut en bas**, la première correspondance s'applique.
- Le trafic **à l'intérieur d'un même VLAN** (ex. Galera entre MYSQL-01 et MYSQL-02, ou HAProxy vers WEB-01) **ne traverse pas pfSense**.

## Alias (*Firewall → Aliases*)

| Alias | Type | Valeur |
|-------|------|--------|
| `HAPROXY` | Host | 10.0.10.2 |
| `WEB_SERVERS` | Host | 10.0.10.1, 10.0.10.4 |
| `GALERA_NODES` | Host | 10.0.20.1, 10.0.20.2, 10.0.20.3 |
| `ADMIN_HOSTS` | Host | 10.0.30.1, 10.0.30.2 |
| `RFC1918` | Network | 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 |
| `WEB_PORTS` | Port | 80, 8080 |
| `ADMIN_PORTS` | Port | 22, 80, 443, 3306, 8080, 8404 |

## WAN

| # | Statut | Action | Proto | Source | Destination | Port | Description |
|---|--------|--------|-------|--------|-------------|------|-------------|
| 1 | Réel | Pass | TCP | any | HAPROXY | 80 | Règle associée au NAT 8081 |
| — | Défaut | Block | any | any | any | any | Implicite |

## VLAN 301 — vWEB (10.0.10.0/24)

| # | Statut | Action | Proto | Source | Destination | Port | Description |
|---|--------|--------|-------|--------|-------------|------|-------------|
| 1 | Réel | Pass | TCP | HAPROXY | GALERA_NODES | 3306 | HAProxy vers Galera |
| 2 | Modèle | Pass | TCP/UDP | vWEB net | vWEB address | 53 | DNS (résolveur pfSense) |
| 3 | Modèle | Pass | UDP | vWEB net | vWEB address | 123 | NTP |
| 4 | Modèle | Block | any | vWEB net | RFC1918 | any | Interdit tout autre accès interne |
| 5 | Modèle | Pass | TCP | vWEB net | any | 80, 443 | Mises à jour (`apt`) vers l'extérieur |

## VLAN 302 — vBDD (10.0.20.0/24)

| # | Statut | Action | Proto | Source | Destination | Port | Description |
|---|--------|--------|-------|--------|-------------|------|-------------|
| 1 | Modèle | Pass | TCP/UDP | vBDD net | vBDD address | 53 | DNS |
| 2 | Modèle | Pass | UDP | vBDD net | vBDD address | 123 | NTP |
| 3 | Modèle | Block | any | vBDD net | RFC1918 | any | Les bases n'initient aucune connexion interne |
| 4 | Modèle | Pass | TCP | vBDD net | any | 80, 443 | Mises à jour (`apt`) |

> Les ports Galera (4567, 4568, 4444) circulent **entre nœuds du même VLAN** : aucune règle pfSense n'est nécessaire. Un pare-feu local (nftables) sur chaque nœud peut les restreindre aux deux autres nœuds — voir [hardening.md](../../docs/07-security/hardening.md).

## VLAN 303 — vADMIN (10.0.30.0/24)

| # | Statut | Action | Proto | Source | Destination | Port | Description |
|---|--------|--------|-------|--------|-------------|------|-------------|
| 1 | Modèle | Pass | TCP | ADMIN_HOSTS | vADMIN address | 443 | Interface web pfSense |
| 2 | Réel | Pass | TCP | ADMIN_HOSTS | vWEB net | 22 | SSH vers vWEB |
| 3 | Réel | Pass | TCP | ADMIN_HOSTS | vBDD net | 22 | SSH vers vBDD |
| 4 | Modèle | Pass | TCP | ADMIN_HOSTS | HAPROXY | 80, 3306, 8080, 8404 | Tests HTTP/SQL et statistiques |
| 5 | Modèle | Pass | TCP | ADMIN_HOSTS | WEB_SERVERS | 80 | Tests directs des backends |
| 6 | Modèle | Pass | TCP | ADMIN_HOSTS | 10.0.10.3 | 80 | Test direct GLPI |
| 7 | Modèle | Pass | ICMP | ADMIN_HOSTS | RFC1918 | — | Ping de diagnostic |
| 8 | Modèle | Pass | TCP/UDP | vADMIN net | vADMIN address | 53 | DNS |
| 9 | Modèle | Pass | TCP | vADMIN net | any | 80, 443 | Mises à jour |

## VLAN 304 — vUSER (10.0.40.0/24)

| # | Statut | Action | Proto | Source | Destination | Port | Description |
|---|--------|--------|-------|--------|-------------|------|-------------|
| 1 | Modèle | Pass | TCP | vUSER net | HAPROXY | WEB_PORTS | WordPress (80) et GLPI (8080) via HAProxy uniquement |
| 2 | Modèle | Pass | TCP/UDP | vUSER net | vUSER address | 53 | DNS |
| 3 | Modèle | Block | any | vUSER net | RFC1918 | any | Aucun accès direct aux serveurs, bases ou admin |
| 4 | Modèle | Pass | TCP | vUSER net | any | 80, 443 | Navigation |

## Vérification

```bash
# SUR ADM-01 : doit réussir
nc -zv 10.0.10.2 3306
# SUR UN POSTE vUSER : doit échouer (timeout) — la base n'est pas joignable depuis les utilisateurs
nc -zv -w 3 10.0.20.1 3306
```

Plan de test complet : [docs/08-tests/network-tests.md](../../docs/08-tests/network-tests.md)
