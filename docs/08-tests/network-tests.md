# Tests réseau

## T01 — Réseaux et routage

**SUR ADM-01**

```bash
NO_COLOR=1 ./scripts/validation/check-network.sh | tee "evidence/test-results/$(date +%F)-T01-network.txt"
```

Complément, sur chaque VM : la passerelle de son VLAN répond.

| VM | Commande | Attendu |
|----|----------|---------|
| WEB-01 | `ping -c 2 10.0.10.254` | Réponse |
| MYSQL-01 | `ping -c 2 10.0.20.254` | Réponse |
| ADM-01 | `ping -c 2 10.0.30.254` | Réponse |

## T02 — SSH

**SUR ADM-01**

```bash
for h in web01 haproxy glpi01 web02 mysql01 mysql02 mysql03; do
  printf '%-8s ' "$h"; ssh -o BatchMode=yes -o ConnectTimeout=5 "$h" hostname || echo "ÉCHEC"
done
```

Attendu : chaque VM répond par son nom d'hôte, **sans demande de mot de passe** (clé).

Négatif : l'authentification par mot de passe est refusée.

```bash
ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password mysql01
# attendu : Permission denied (publickey).
```

## T18 — NAT

**SUR UN POSTE DU RÉSEAU LABO**

```bash
curl -sI http://10.4.0.198:8081 | grep -Ei '^HTTP/|x-served-by'
```

Attendu : réponse HTTP et `X-Served-By: WEB-0X`.

## T19 — Filtrage (flux interdits)

Un pare-feu se valide en testant **ce qui doit être bloqué**.

| Depuis | Commande | Attendu | Règle vérifiée |
|--------|----------|---------|----------------|
| Poste vUSER | `nc -zv -w 3 10.0.20.1 3306` | Timeout | vUSER ne joint pas vBDD |
| Poste vUSER | `nc -zv -w 3 10.0.10.1 22` | Timeout | vUSER ne joint pas SSH |
| Poste vUSER | `nc -zv -w 3 10.0.10.2 8404` | Timeout | Stats HAProxy réservées à vADMIN |
| Poste vUSER | `curl -sI http://10.0.10.2/` | `200`/`30x` | vUSER joint WordPress via HAProxy |
| WEB-01 | `nc -zv -w 3 10.0.20.1 3306` | Timeout | Seul HAProxy joint les bases |
| HAPROXY | `nc -zv -w 3 10.0.20.1 3306` | `succeeded` | HAProxy joint les bases |
| MYSQL-01 | `nc -zv -w 3 10.0.10.1 80` | Timeout | Les bases n'initient pas de connexion vers vWEB |
| Réseau labo | `nc -zv -w 3 10.4.0.198 3306` | Timeout | Aucune publication SQL |

Capture : `02-pfsense-firewall-vweb.png` (règles) ; journal pare-feu montrant les blocages.

> `nc` est fourni par le paquet `netcat-openbsd` (`sudo apt install netcat-openbsd`).
