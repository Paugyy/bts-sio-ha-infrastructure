# Politique de sécurité

Ce dépôt documente une infrastructure réelle de laboratoire. Sa publication impose des règles strictes : **un dépôt public ne doit jamais permettre de se connecter à l'infrastructure qu'il décrit**.

## Règles absolues

| Interdit dans le dépôt | Remplacement |
|------------------------|--------------|
| Mot de passe (SQL, Linux, pfSense, WordPress, GLPI, HAProxy stats) | `<PASSWORD>` ou `<SECRET>` |
| Clé privée SSH (`id_rsa`, `id_ed25519`, `*.pem`, `*.ppk`) | `<SSH_PRIVATE_KEY>` — jamais versionnée, même chiffrée |
| Clés et sels WordPress (`AUTH_KEY`, `SECURE_AUTH_SALT`…) | `<SECRET>` + lien vers le générateur officiel |
| Jetons d'API, tokens GitHub, tokens Proxmox | `<TOKEN>` |
| Hash de mots de passe (`/etc/shadow`, `mysql.user`, export pfSense) | `********` |
| Export complet `config.xml` de pfSense | Jamais publié (contient hash et clés) |
| Sauvegardes (`*.sql`, `*.vma`, `*.tar.gz`) | Jamais publiées |
| IP publiques personnelles, e-mails personnels, noms complets inutiles | Placeholders (`<PUBLIC_IP>`, `<AUTHOR>`) |

## Fichiers `.example`

Toutes les configurations sont publiées sous la forme `*.example` :

```bash
# SUR HAPROXY
sudo cp configs/haproxy/haproxy.cfg.example /etc/haproxy/haproxy.cfg
sudo nano /etc/haproxy/haproxy.cfg      # remplacer chaque <PLACEHOLDER>
```

Le fichier réel (`haproxy.cfg`, `wp-config.php`, `60-galera.cnf`…) est ignoré par [`.gitignore`](.gitignore) s'il est copié par erreur dans `configs/`.

## Adresses IP

Les adresses utilisées (`10.0.0.0/8`, `10.4.0.0/24`) sont des adresses **privées RFC 1918** d'un réseau de laboratoire isolé ; elles sont publiées volontairement pour la reproductibilité. Si vous adaptez ce dépôt à un réseau d'entreprise, remplacez les adresses réelles avant publication (le [générateur](generator/README.md) le fait pour vous).

## Contrôles automatiques

| Contrôle | Où | Ce qu'il détecte |
|----------|----|------------------|
| [`check-repository.sh`](scripts/validation/check-repository.sh) | Local (`make check`) et CI | Fichiers sensibles (`id_rsa`, `*.pem`, `.env`…), motifs de secrets (`BEGIN … PRIVATE KEY`, `password = valeur`) |
| [`validate-configs.yml`](.github/workflows/validate-configs.yml) | GitHub Actions | Mêmes contrôles + configurations non vides |
| GitHub Secret Scanning + Push Protection | Paramètres du dépôt | Tokens de fournisseurs connus |
| Dependabot | [`.github/dependabot.yml`](.github/dependabot.yml) | Versions des GitHub Actions |

Voir [docs/07-security/secrets-management.md](docs/07-security/secrets-management.md) pour l'activation et les limites de ces outils.

## Avant chaque push

```bash
# SUR LE POSTE DE DÉVELOPPEMENT
make check
git diff --cached | grep -Ei 'password|secret|token|BEGIN .*PRIVATE' || echo "Aucun motif suspect"
```

Checklist complète : [docs/11-bts-sio/pre-publish-checklist.md](docs/11-bts-sio/pre-publish-checklist.md)

## Si un secret a été poussé

1. **Considérer le secret comme compromis** : le supprimer du dépôt ne suffit pas, il reste dans l'historique et a pu être copié.
2. **Changer immédiatement** le mot de passe ou révoquer la clé / le token concerné.
3. Nettoyer l'historique (`git filter-repo` ou BFG), puis `git push --force` après accord des contributeurs.
4. Documenter l'incident dans [docs/09-troubleshooting/incidents.md](docs/09-troubleshooting/incidents.md) (sans recopier le secret).

## Signaler un problème de sécurité

- **Ne pas ouvrir d'issue publique** contenant un secret ou une vulnérabilité exploitable.
- Utiliser **GitHub → onglet Security → Report a vulnerability** (signalement privé), si l'option est activée sur le dépôt.
- À défaut, ouvrir une issue publique **sans détail sensible** demandant un canal de contact privé.

Délai de prise en compte visé : 7 jours. Ce projet étant pédagogique, aucun engagement de niveau de service n'est garanti.

## Versions concernées

| Version | Suivie |
|---------|--------|
| 1.0.x | Oui |
| < 1.0 | Non |
