# Contribuer

Merci de contribuer à ce dépôt. Les règles ci-dessous garantissent un historique lisible, une documentation à jour et **l'absence de secrets**.

## Branches

| Branche | Rôle | Protégée |
|---------|------|----------|
| `main` | Version stable, taguée (`v1.0.0`…) — reflète l'infrastructure validée | Oui |
| `develop` | Intégration des travaux en cours | Oui |
| `feature/*` | Nouvelle fonctionnalité d'infrastructure ou de doc (`feature/keepalived-vip`) | Non |
| `fix/*` | Correction (`fix/mysql02-bind-address`) | Non |
| `docs/*` | Documentation seule (`docs/galera-recovery`) | Non |

Flux :

```text
feature/* ─┐
fix/*     ─┼──► develop ──(release)──► main ──► tag vX.Y.Z
docs/*    ─┘
```

```bash
# SUR LE POSTE DE DÉVELOPPEMENT
git switch develop
git pull
git switch -c feature/haproxy-secondary
# ... travail ...
git push -u origin feature/haproxy-secondary
# puis ouvrir une Pull Request vers develop
```

## Convention de commits

Format [Conventional Commits](https://www.conventionalcommits.org/fr/) :

```text
<type>(<portée>): <description à l'impératif, en anglais, minuscule>
```

| Type | Usage |
|------|-------|
| `feat` | Nouvelle capacité (service, configuration, script) |
| `fix` | Correction d'une erreur |
| `docs` | Documentation uniquement |
| `test` | Ajout ou modification de tests / procédures de test |
| `chore` | Maintenance du dépôt (CI, .gitignore…) |
| `refactor` | Réorganisation sans changement de comportement |
| `ci` | Workflows GitHub Actions |

Portées recommandées : `network`, `pfsense`, `galera`, `mysql01`, `mysql02`, `mysql03`, `haproxy`, `wordpress`, `web01`, `web02`, `glpi`, `ssh`, `security`, `backup`, `generator`, `bts`, `repo`.

Exemples :

```text
feat(haproxy): add wordpress load balancing
feat(galera): add three-node cluster configuration
fix(mysql02): correct bind address
docs(wordpress): add failover procedure
test(haproxy): add backend health check validation
chore(repo): add shellcheck workflow
```

## Pull Requests

1. Une PR = un sujet.
2. Remplir le [template](.github/PULL_REQUEST_TEMPLATE.md), notamment les **tests réalisés** (avec sorties ou captures).
3. La CI doit être verte : markdownlint, ShellCheck, validation des configurations, liens.
4. Au moins une relecture avant fusion dans `develop` ou `main`.
5. Fusion par *squash* pour les petites PR, *merge commit* pour les releases.

## Tests obligatoires

| Si vous modifiez… | Vous devez… |
|-------------------|-------------|
| Un script `scripts/**/*.sh` | Passer `shellcheck`, l'exécuter au moins une fois sur la VM cible, garder le mode simulation par défaut |
| Une configuration `configs/**` | Vérifier la syntaxe (`haproxy -c`, `apachectl configtest`, `php -l`) sur une VM de test |
| Le cluster Galera | Rejouer [check-galera.sh](scripts/validation/check-galera.sh) sur les 3 nœuds |
| HAProxy ou WordPress | Rejouer [wordpress-failover.md](docs/08-tests/wordpress-failover.md) |
| Le générateur | Ouvrir `generator/index.html`, charger l'exemple de référence, vérifier les fichiers générés |

```bash
# SUR LE POSTE DE DÉVELOPPEMENT — avant chaque push
make check
make lint
```

## Documentation

- Langue : **français** ; noms de fichiers : **anglais** ; commandes et configurations : syntaxe native.
- **Chaque commande précise la machine** sur laquelle elle s'exécute (`# SUR MYSQL-01`).
- Distinguer clairement : configuration **réelle**, **exemple**, **test à réaliser**, **amélioration future**.
- Tout incident résolu est ajouté à [docs/09-troubleshooting/incidents.md](docs/09-troubleshooting/incidents.md) au format Symptôme / Cause / Diagnostic / Commandes / Correction / Validation.
- Mettre à jour [CHANGELOG.md](CHANGELOG.md) dans la section `[Unreleased]`.

## Sécurité

- Lire [SECURITY.md](SECURITY.md) avant la première contribution.
- Aucun secret, aucune clé privée, aucun export pfSense, aucune sauvegarde.
- Les captures d'écran doivent être **anonymisées** (mots de passe, cookies, tokens masqués).

## Releases

```bash
# SUR LE POSTE DE DÉVELOPPEMENT — après fusion de develop dans main
git switch main && git pull
git tag -a v1.1.0 -m "v1.1.0"
git push origin v1.1.0
```

Puis créer la release GitHub à partir du tag (voir [docs/12-project-management/release-v1.0.0.md](docs/12-project-management/release-v1.0.0.md)).
