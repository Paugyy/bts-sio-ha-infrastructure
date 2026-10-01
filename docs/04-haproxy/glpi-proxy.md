# HAProxy — Publication de GLPI

## Configuration

```haproxy
frontend fe_glpi
    bind 10.0.10.2:8080
    option forwardfor
    http-request set-header X-Forwarded-Proto http
    default_backend be_glpi

backend be_glpi
    option httpchk
    http-check send meth GET uri / ver HTTP/1.1 hdr Host 10.0.10.3
    http-check expect status 200-399
    http-response set-header X-Served-By %[srv_name]
    server GLPI-01 10.0.10.3:80 check inter 5s fall 3 rise 2
```

## Pourquoi publier GLPI via HAProxy alors qu'il n'y a qu'un serveur ?

| Raison | Explication |
|--------|-------------|
| Point d'entrée unique | Utilisateurs et règles pfSense ne connaissent que `10.0.10.2` |
| Évolutivité | Ajouter un GLPI-02 = ajouter une ligne `server`, sans toucher aux clients |
| Visibilité | État de GLPI visible dans la page de statistiques |
| Sécurité | vUSER n'a besoin d'aucun accès direct à GLPI-01 |

## Pourquoi le port 8080 ?

Le port 80 de HAProxy est déjà utilisé par WordPress. Deux solutions :

| Solution | Configuration | Choix |
|----------|---------------|-------|
| Port distinct | `bind 10.0.10.2:8080` | **Retenu** : simple, sans DNS |
| Même port, routage par nom d'hôte | `acl is_glpi hdr(host) -i glpi.lab.local` + `use_backend be_glpi if is_glpi` | Nécessite un DNS interne (amélioration future) |

## Vérification

```bash
# SUR ADM-01
./scripts/validation/check-glpi.sh
curl -sI http://10.0.10.2:8080/ | grep -Ei 'HTTP/|X-Served-By'
```

Configuration côté GLPI : [06-glpi/haproxy.md](../06-glpi/haproxy.md)
