# HAProxy — Répartition WordPress

## Configuration

```haproxy
frontend fe_wordpress
    bind 10.0.10.2:80
    option forwardfor
    http-request set-header X-Forwarded-Proto http
    default_backend be_wordpress

backend be_wordpress
    balance roundrobin
    option httpchk
    http-check send meth GET uri /wp-login.php ver HTTP/1.1 hdr Host 10.0.10.2
    http-check expect status 200-399
    cookie SRV_WP insert indirect nocache httponly
    http-response set-header X-Served-By %[srv_name]
    default-server inter 3s fall 3 rise 2
    server WEB-01 10.0.10.1:80 check cookie web01
    server WEB-02 10.0.10.4:80 check cookie web02
```

## Explication

| Directive | Rôle |
|-----------|------|
| `mode http` (hérité de `defaults`) | HAProxy comprend HTTP (couche 7) : en-têtes, cookies, codes de retour |
| `option forwardfor` | Ajoute `X-Forwarded-For: <IP client>` ; Apache le lit via `mod_remoteip` pour journaliser la vraie IP |
| `balance roundrobin` | Alternance WEB-01 / WEB-02 |
| `option httpchk` + `http-check send` | Health-check applicatif sur `/wp-login.php` : teste Apache **et** PHP **et** la base |
| `http-check expect status 200-399` | Un `302` (redirection) est sain ; un `500` ou `503` ne l'est pas |
| `cookie SRV_WP insert indirect nocache httponly` | HAProxy pose un cookie indiquant le serveur : un administrateur connecté reste sur le même serveur |
| `X-Served-By %[srv_name]` | Indique quel serveur a répondu : rend le failover **visible** |

## Pourquoi un health-check sur `/wp-login.php` ?

| Check | Détecte Apache arrêté | Détecte PHP cassé | Détecte base inaccessible |
|-------|-----------------------|-------------------|---------------------------|
| TCP simple (`check` seul) | Oui | Non | Non |
| HTTP sur `/` | Oui | Oui | Partiellement (selon cache) |
| HTTP sur `/wp-login.php` | Oui | Oui | Oui (WordPress interroge la base) |

## Persistance de session

Sans persistance, un utilisateur connecté à `wp-admin` alterne entre WEB-01 et WEB-02. Comme les **clés et sels** de `wp-config.php` sont identiques sur les deux serveurs, la session reste valide ; la persistance n'est donc pas strictement nécessaire pour WordPress, mais elle :

- évite des incohérences pendant une synchronisation de fichiers ;
- facilite le diagnostic (un utilisateur = un serveur).

Si le serveur du cookie tombe, `option redispatch` envoie le client sur l'autre serveur.

## Vérification

```bash
# SUR ADM-01 — sans cookie : alternance
for i in 1 2 3 4; do curl -sI http://10.0.10.2 | grep -i x-served-by; done

# Avec cookie : persistance
curl -s -c /tmp/cj -o /dev/null http://10.0.10.2/
for i in 1 2 3; do curl -s -b /tmp/cj -o /dev/null -D - http://10.0.10.2/ | grep -i x-served-by; done
```

Tests associés : T13 ([haproxy-tests.md](../08-tests/haproxy-tests.md)), T14 à T16 ([wordpress-failover.md](../08-tests/wordpress-failover.md)).
