# pfSense — NAT

Tableau de référence : [configs/pfsense/nat-rules.md](../../configs/pfsense/nat-rules.md)

## Port Forward WordPress (réel)

**SUR PFSENSE** (*Firewall → NAT → Port Forward → Add*)

| Champ | Valeur |
|-------|--------|
| Interface | WAN |
| Protocol | TCP |
| Destination | WAN address |
| Destination port range | 8081 |
| Redirect target IP | 10.0.10.2 |
| Redirect target port | 80 (HTTP) |
| Description | WordPress via HAProxy |
| Filter rule association | Add associated filter rule |

## Pourquoi cibler HAProxy et pas un serveur web ?

| Cible du NAT | Panne de WEB-01 | Panne de WEB-02 |
|--------------|-----------------|-----------------|
| WEB-01 (10.0.10.1) | **Site coupé** | Aucun effet (WEB-02 n'est jamais utilisé) |
| HAProxy (10.0.10.2) | Bascule sur WEB-02 | Bascule sur WEB-01 |

Cibler un serveur web directement annulerait toute la redondance.

## Pourquoi le port 8081 ?

C'est le port retenu dans le lab. Utiliser un port externe dédié plutôt que 80 permet de publier plusieurs services sur la même IP WAN (8081 WordPress, 8082 GLPI…) et d'éviter tout conflit avec l'interface d'administration de pfSense. Côté interne, HAProxy reste sur le port standard 80. Le port externe est un paramètre : l'adapter à votre réseau.

## Effet sur WordPress

WordPress mémorise son URL (`siteurl`, `home`). Si le site a été installé via `http://10.0.10.2`, un visiteur arrivant par `http://10.4.0.198:8081` peut être **redirigé** vers `10.0.10.2`, injoignable depuis le WAN. Choisir l'URL de référence en fonction des clients visés et la fixer dans `wp-config.php` (`WP_HOME`, `WP_SITEURL`) — voir [05-wordpress/troubleshooting.md](../05-wordpress/troubleshooting.md).

## Vérification

```bash
# SUR UN POSTE DU RÉSEAU LABO (10.4.0.0/24)
curl -sI http://10.4.0.198:8081 | grep -Ei 'HTTP/|X-Served-By'
```

Test T18 de la [matrice de validation](../08-tests/validation-matrix.md).
