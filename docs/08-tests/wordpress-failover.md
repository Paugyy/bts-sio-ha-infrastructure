# Test de failover WordPress

Tests **T14** (panne WEB-01), **T15** (panne WEB-02) et **T16** (réintégration).

## Objectif

Démontrer que l'arrêt d'un serveur web **n'interrompt pas** le site : HAProxy détecte la panne et envoie tout le trafic vers le serveur restant, puis réintègre automatiquement le serveur à son retour.

## Prérequis

- [ ] T11, T12, T13 réussis (les deux serveurs répondent, alternance via HAProxy).
- [ ] Accès SSH à WEB-01 et WEB-02 depuis ADM-01.
- [ ] Page de statistiques HAProxy ouverte (`http://10.0.10.2:8404/stats`) pour la démonstration visuelle.

## Observation continue (recommandée)

**SUR ADM-01** — terminal dédié, laissé ouvert pendant tout le test :

```bash
while true; do
  printf '%s  ' "$(date +%T)"
  curl -s -o /dev/null -D - --max-time 3 http://10.0.10.2 | grep -Ei '^HTTP/|x-served-by' | tr -d '\r' | tr '\n' ' '
  echo
  sleep 1
done
```

## T14 — WEB-01 arrêté : WEB-02 doit continuer

### 1. État initial

**SUR ADM-01**

```bash
curl -I http://10.0.10.2
```

Plusieurs requêtes : `X-Served-By` alterne `WEB-01` / `WEB-02`.

### 2. Panne

**SUR WEB-01**

```bash
sudo systemctl stop apache2
```

### 3. Vérification

**SUR ADM-01**

```bash
curl -I http://10.0.10.2
```

| Critère | Attendu |
|---------|---------|
| Code HTTP | `200` (ou `30x`) — **jamais** `503` ni erreur de connexion |
| `X-Served-By` | `WEB-02` uniquement |
| Page de stats | WEB-01 **DOWN** (rouge) après ~9 s |

Capture : `08-failover-web01-down.png`

### 4. Retour (T16)

**SUR WEB-01**

```bash
sudo systemctl start apache2
```

**SUR ADM-01** — après ~6 s :

```bash
curl -I http://10.0.10.2
```

`X-Served-By` alterne à nouveau `WEB-01` / `WEB-02` : **réintégration automatique**, sans action sur HAProxy.

## T15 — WEB-02 arrêté : WEB-01 doit continuer

Procédure identique, en inversant les rôles.

**SUR WEB-02**

```bash
sudo systemctl stop apache2
```

**SUR ADM-01**

```bash
curl -I http://10.0.10.2          # X-Served-By: WEB-01 uniquement
```

Capture : `09-failover-web02-down.png`

**SUR WEB-02**

```bash
sudo systemctl start apache2
```

## Version scriptée

Les scripts reproduisent exactement cette procédure (mode guidé : ils indiquent la commande à lancer et attendent la confirmation de l'opérateur) :

```bash
# SUR ADM-01
./scripts/failover/test-web01-failure.sh --save     # T14 + T16
./scripts/failover/test-web02-failure.sh --save     # T15 + T16
```

Option `--auto` : le script arrête et redémarre Apache lui-même via SSH (alias `web01`/`web02` de `~/.ssh/config`), après confirmation, et relance Apache s'il est interrompu.

## Interprétation

| Observation | Explication |
|-------------|-------------|
| Aucune erreur, même dans les premières secondes | Requêtes vers WEB-01 refusées puis **rejouées** sur WEB-02 (`retries 3` + `option redispatch`) |
| Quelques erreurs dans les premières secondes | Possible si le serveur ne refuse pas mais **ne répond plus** (VM figée) : les requêtes attendent le timeout jusqu'à détection (`fall 3`) |
| `503` permanent | Les deux serveurs sont DOWN : vérifier WEB-02 et le health-check |

## Variante : arrêt de la VM

Simuler une panne matérielle : **SUR L'HÔTE PROXMOX**, *Shutdown* (ou *Stop*) de la VM WEB-01. Le comportement attendu est le même ; la détection repose alors sur le timeout de connexion.
