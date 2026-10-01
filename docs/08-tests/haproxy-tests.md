# Tests HAProxy

## État général

**SUR HAPROXY**

```bash
NO_COLOR=1 ./scripts/validation/check-haproxy.sh | tee "evidence/test-results/$(date +%F)-haproxy-status.txt"
```

Attendu : service actif, syntaxe valide, ports 80/8080/3306/8404 en écoute, tous les serveurs `UP`.

Capture : page `http://10.0.10.2:8404/stats` depuis ADM-01 → `05-haproxy-status.png`

## T09 — HAProxy SQL

**SUR WEB-01**

```bash
mariadb -h 10.0.10.2 -P 3306 -u wordpress -p -e 'SELECT @@hostname, @@wsrep_node_name;'
```

Attendu : connexion réussie, nom d'un nœud Galera.

## T10 — Round-robin SQL

**SUR HAPROXY**

```bash
NO_COLOR=1 ./scripts/utilities/test-sql-round-robin.sh -n 9 | tee "evidence/test-results/$(date +%F)-T10-sql-round-robin.txt"
```

Attendu : 9/9 connexions réussies, **3 nœuds distincts**.

## T13 — HAProxy HTTP

**SUR ADM-01**

```bash
for i in $(seq 1 6); do curl -s -o /dev/null -D - http://10.0.10.2/ | grep -Ei '^HTTP/|x-served-by'; done
```

Attendu : codes `200` (ou `30x`), `X-Served-By` alternant **WEB-01** / **WEB-02**.

## Test complémentaire — health-check applicatif

Vérifie qu'un serveur dont l'**application** est cassée est retiré, alors qu'Apache tourne toujours (un check TCP ne verrait rien). On simule la panne en rendant `/wp-login.php` introuvable (réponse `404`, hors de la plage `200-399` attendue).

**SUR WEB-02**

```bash
sudo mv /var/www/wordpress/wp-login.php /var/www/wordpress/wp-login.php.test-hc
```

**SUR ADM-01** (après ~10 s)

```bash
for i in 1 2 3 4; do curl -sI http://10.0.10.2/ | grep -i x-served-by; done   # uniquement WEB-01
```

**SUR WEB-02** (remise en état **immédiate**)

```bash
sudo mv /var/www/wordpress/wp-login.php.test-hc /var/www/wordpress/wp-login.php
```

Ce test prouve l'intérêt de `option httpchk` sur `/wp-login.php` par rapport à un simple check TCP.

## T17 — GLPI via HAProxy

**SUR ADM-01**

```bash
NO_COLOR=1 ./scripts/validation/check-glpi.sh | tee "evidence/test-results/$(date +%F)-T17-glpi.txt"
```

Attendu : GLPI-01 UP en direct et via `10.0.10.2:8080`, page identifiée comme GLPI.
