# HAProxy — Installation

## Fiche

| Élément | Valeur |
|---------|--------|
| VM | HAPROXY |
| IP | 10.0.10.2/24, passerelle 10.0.10.254 |
| VLAN | 301 — vWEB |
| OS | Debian 12 |
| Logiciel | HAProxy 2.6 (paquet Debian) |
| Compte d'administration | `haproxyadmin` (**pas** `haproxy` — voir ci-dessous) |
| Configuration | [configs/haproxy/haproxy.cfg.example](../../configs/haproxy/haproxy.cfg.example) |

## Compte d'administration : ne pas l'appeler « haproxy »

Lors de l'installation de Debian, l'installateur demande de créer un utilisateur. Le nommer `haproxy` crée un compte **humain** (uid ≥ 1000, shell, home) qui **entre en conflit** avec le compte **système** que le paquet `haproxy` veut créer pour faire tourner le service. Résultat : erreurs à l'installation du paquet ou service lancé avec un compte doté d'un shell — à éviter.

**Règle** : compte humain `haproxyadmin`, compte système `haproxy` laissé au paquet. Détail : [incident INC-08](../09-troubleshooting/incidents.md#inc-08--conflit-avec-le-compte-système-haproxy).

```bash
# SUR HAPROXY — vérification
getent passwd haproxy        # attendu : uid < 1000, shell /usr/sbin/nologin
```

## Installation

**SUR HAPROXY**

```bash
sudo ./scripts/install/install-haproxy.sh            # simulation
sudo ./scripts/install/install-haproxy.sh --apply    # exécution
```

Ou manuellement :

```bash
sudo apt update
sudo apt install -y haproxy mariadb-client socat curl
haproxy -v
```

## Compte de health-check SQL

**SUR MYSQL-01** (répliqué sur les 3 nœuds)

```sql
-- sudo mariadb
CREATE USER 'haproxy_check'@'10.0.10.2';
-- Aucun GRANT : le compte peut seulement ouvrir une session.
```

## Configuration

**SUR HAPROXY**

```bash
sudo cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.orig
sudo cp configs/haproxy/haproxy.cfg.example /etc/haproxy/haproxy.cfg
sudo nano /etc/haproxy/haproxy.cfg                 # remplacer <PASSWORD> (page de stats)
sudo haproxy -c -f /etc/haproxy/haproxy.cfg        # "Configuration file is valid"
sudo systemctl enable --now haproxy
sudo systemctl reload haproxy
```

`reload` applique la nouvelle configuration **sans couper** les connexions en cours ; `restart` les coupe. Toujours lancer `haproxy -c` avant.

## Vérification

```bash
# SUR HAPROXY
./scripts/validation/check-haproxy.sh
sudo ss -ltnp | grep haproxy        # 80, 3306, 8080, 8404 sur 10.0.10.2
```

Page de statistiques depuis ADM-01 : `http://10.0.10.2:8404/stats` — capture attendue `evidence/screenshots/05-haproxy-status.png`.

Suite : [sql-load-balancing.md](sql-load-balancing.md), [wordpress-load-balancing.md](wordpress-load-balancing.md)
