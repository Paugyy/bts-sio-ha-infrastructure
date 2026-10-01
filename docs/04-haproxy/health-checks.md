# HAProxy — Health-checks

Un health-check est un test périodique qui décide si un serveur reçoit du trafic. **Sans health-check, il n'y a pas de haute disponibilité** : HAProxy continuerait d'envoyer des requêtes vers un serveur mort.

## Paramètres

| Paramètre | Valeur | Effet |
|-----------|--------|-------|
| `inter 3s` | 3 secondes | Intervalle entre deux tests |
| `fall 3` | 3 échecs | Serveur déclaré **DOWN** après ~9 s |
| `rise 2` | 2 succès | Serveur déclaré **UP** après ~6 s |
| `timeout check 3s` | 3 secondes | Délai maximum d'une réponse au test |

Compromis : des valeurs plus basses détectent plus vite une panne mais risquent des **faux positifs** (un serveur lent retiré à tort) et ajoutent de la charge.

## Checks par service

| Backend | Type | Ce qui est testé | Ce qui n'est **pas** testé |
|---------|------|------------------|---------------------------|
| `be_wordpress` | HTTP GET `/wp-login.php`, attendu 2xx/3xx | Apache, PHP, accès base | Contenu de la page |
| `be_glpi` | HTTP GET `/`, attendu 2xx/3xx | Apache, PHP, routage GLPI | — |
| `galera_cluster` | `mysql-check` (handshake + login) | MariaDB démarré et joignable | **État Galera** (`Synced`, `Primary`) |

## Limite du check SQL et amélioration

Un nœud peut **accepter une connexion** tout en étant inutilisable :

- `Donor/Desynced` pendant un SST rsync (bloqué en lecture/écriture) ;
- `non-Primary` après une perte de quorum (`WSREP has not yet prepared node for application use`).

`mysql-check` le considère sain. **Amélioration (roadmap)** : check *wsrep-aware* via un petit service HTTP sur chaque nœud (ex. script `clustercheck` exposé sur le port 9200) qui renvoie `200` uniquement si `wsrep_local_state = 4` (Synced) :

```haproxy
# Exemple — amélioration future, NON déployée
listen galera_cluster
    bind 10.0.10.2:3306
    mode tcp
    balance roundrobin
    option httpchk
    http-check expect status 200
    default-server port 9200 inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
    server MYSQL-01 10.0.20.1:3306 check
    server MYSQL-02 10.0.20.2:3306 check
    server MYSQL-03 10.0.20.3:3306 check
```

## Observer les checks

```bash
# SUR HAPROXY — journal en direct
sudo journalctl -u haproxy -f
# Exemple de ligne lors d'une panne :
#   Server be_wordpress/WEB-01 is DOWN, reason: Layer4 connection problem ...

# État instantané
./scripts/validation/check-haproxy.sh
echo "show servers state" | sudo socat stdio /run/haproxy/admin.sock
```

Page de statistiques : `http://10.0.10.2:8404/stats` (depuis vADMIN) — colonne *Status* et *LastChk*.
