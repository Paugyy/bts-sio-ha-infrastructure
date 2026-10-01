# Sécurité — Gestion des secrets

## Inventaire des secrets de l'infrastructure

| Secret | Où il est utilisé | Où il est stocké | Dans le dépôt |
|--------|-------------------|------------------|---------------|
| Mot de passe admin pfSense | Interface web pfSense | Gestionnaire de mots de passe | Jamais |
| Mot de passe `wordpress`@`10.0.10.2` | `wp-config.php` (WEB-01, WEB-02) | Gestionnaire + fichier `640` sur les VM | `<SECRET>` |
| Clés/sels WordPress | `wp-config.php` | Fichier sur les VM | `<SECRET>` |
| Mot de passe `glpi`@`10.0.10.2` | `config_db.php` (GLPI-01) | Gestionnaire + fichier sur la VM | `<PASSWORD>` |
| Mot de passe des stats HAProxy | `haproxy.cfg` | Gestionnaire + fichier sur la VM | `<PASSWORD>` |
| Clé privée SSH d'administration | ADM-01, poste admin | `~/.ssh/` (`600`), phrase de passe | Jamais |
| Comptes WordPress / GLPI | Interfaces web | Gestionnaire de mots de passe | Jamais |
| Export `config.xml` pfSense | Restauration | Stockage chiffré hors lab | Jamais |

Le compte `haproxy_check` n'a **pas** de mot de passe par conception (aucun privilège, restreint à `10.0.10.2`) : ce n'est pas un secret, mais une surface à limiter (voir [least-privilege.md](least-privilege.md)).

## Règles

1. **Aucun secret dans Git**, même dans un dépôt privé, même « temporairement » : l'historique est conservé.
2. Configurations publiées en **`.example`** avec placeholders.
3. Mots de passe **uniques** par service, générés aléatoirement (≥ 20 caractères).
4. Mots de passe **demandés à l'exécution** par les scripts (`read -s`), jamais en argument (`-pMotDePasse` est visible dans `ps` et l'historique).
5. Fichiers contenant des secrets sur les VM : propriétaire `root` ou compte de service, droits `600`/`640`.

## Garde-fous du dépôt

| Outil | Rôle | Coût |
|-------|------|------|
| [`.gitignore`](../../.gitignore) | Empêche l'ajout accidentel de clés, `.env`, sauvegardes, configs réelles | Aucun |
| [`check-repository.sh`](../../scripts/validation/check-repository.sh) | Recherche fichiers sensibles et motifs de secrets (local + CI) | Aucun |
| **GitHub Secret Scanning** | Détecte les formats de tokens connus (GitHub, AWS, Slack…) dans tout l'historique | Gratuit pour les dépôts publics |
| **Push Protection** | **Bloque** un push contenant un token reconnu | Gratuit pour les dépôts publics |
| **Dependabot** | Tient à jour les versions des GitHub Actions ([dependabot.yml](../../.github/dependabot.yml)) | Aucun |

### Activer Secret Scanning et Push Protection

*Settings → Code security → Secret Protection* (intitulé variable selon l'interface GitHub) → activer **Secret scanning** et **Push protection**.

### Et CodeQL ?

CodeQL analyse du code applicatif (JavaScript, Python…) à la recherche de vulnérabilités. Ici, seul le générateur contient du JavaScript, exécuté localement sans serveur ni entrée distante. CodeQL n'apporterait qu'un gain marginal pour une complexité de CI supplémentaire : **non retenu** en v1.0.0. Il peut être activé en un clic (*Code scanning → Default setup*) si le générateur évolue.

### Limites

Ces outils reconnaissent des **formats** (préfixes de tokens, en-têtes de clés). Un mot de passe comme `Lab2026!` dans un fichier de configuration ne sera détecté ni par GitHub ni par la plupart des scanners. La vraie protection reste la **discipline** : `.example`, placeholders, relecture du `git diff` avant commit.

## Avant chaque commit

```bash
# SUR LE POSTE DE DÉVELOPPEMENT
git diff --cached
make check
```

## En cas de fuite

Procédure : [SECURITY.md](../../SECURITY.md#si-un-secret-a-été-poussé) — **changer le secret d'abord**, nettoyer l'historique ensuite.
