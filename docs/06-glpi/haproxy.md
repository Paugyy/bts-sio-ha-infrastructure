# GLPI — Intégration HAProxy

GLPI utilise HAProxy **dans les deux sens** :

```text
Utilisateurs ──► HAProxy :8080 ──► GLPI-01 :80          (HTTP, frontend fe_glpi)
GLPI-01      ──► HAProxy :3306 ──► MYSQL-01/02/03       (SQL, listen galera_cluster)
```

## Côté HTTP

Configuration et justification : [04-haproxy/glpi-proxy.md](../04-haproxy/glpi-proxy.md)

Points d'attention spécifiques à GLPI :

| Sujet | Effet | Mesure |
|-------|-------|--------|
| URL de l'application | GLPI génère certains liens absolus (notifications, e-mails) à partir de son URL configurée | *Configuration → Générale → URL de l'application* = `http://10.0.10.2:8080` |
| IP des utilisateurs dans l'historique | Sans traitement, GLPI enregistre 10.0.10.2 | `mod_remoteip` dans le vhost (déjà en place) |

## Côté SQL

GLPI ouvre des connexions SQL **courtes** (une par requête HTTP). Elles sont réparties par HAProxy entre les 3 nœuds. Si un nœud tombe pendant une requête, cette requête peut échouer ; la suivante est envoyée sur un nœud sain.

## Test

```bash
# SUR ADM-01
curl -sI http://10.0.10.2:8080/ | grep -Ei 'HTTP/|X-Served-By'      # X-Served-By: GLPI-01
./scripts/validation/check-glpi.sh
```

Test T17 de la [matrice de validation](../08-tests/validation-matrix.md).
