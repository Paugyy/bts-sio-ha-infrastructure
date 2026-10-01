# Workflow Git

## Initialisation du dépôt

```bash
# SUR LE POSTE DE DÉVELOPPEMENT
cd bts-sio-ha-infrastructure
git init
git add .
# Sous Windows : enregistrer le bit exécutable des scripts (sinon la CI échoue)
git update-index --chmod=+x scripts/install/*.sh scripts/validation/*.sh scripts/failover/*.sh scripts/backup/*.sh scripts/utilities/*.sh
git commit -m "chore(repo): initialize BTS SIO HA infrastructure"
git branch -M main
git remote add origin https://github.com/<GITHUB_USER>/bts-sio-ha-infrastructure.git
git push -u origin main

# Branche d'intégration
git switch -c develop
git push -u origin develop
```

## Configuration GitHub après le premier push

| Réglage | Où | Valeur |
|---------|----|--------|
| Description | *About* (roue dentée) | Voir ci-dessous |
| Topics | *About* | Voir ci-dessous |
| Protection de `main` | *Settings → Branches* (ou *Rules*) | PR obligatoire, CI verte requise |
| Secret scanning + Push protection | *Settings → Code security* | Activés |
| Signalement privé de vulnérabilité | *Settings → Code security* | Activé |
| GitHub Pages (optionnel) | *Settings → Pages* | `main` / `(root)` |
| Labels | *Issues → Labels* | [labels.md](labels.md) |

**Description** (< 350 caractères) :

```text
Infrastructure haute disponibilité réalisée en BTS SIO SISR : pfSense et 4 VLAN, HAProxy (HTTP + SQL), cluster MariaDB Galera 3 nœuds, WordPress redondé sur 2 serveurs, GLPI. Documentation complète, configurations anonymisées, scripts de validation et procédures de failover testables.
```

**Topics** :

```text
bts-sio sisr proxmox pfsense haproxy mariadb galera wordpress glpi linux debian high-availability load-balancing vlan homelab infrastructure
```

Avec GitHub CLI :

```bash
gh repo edit --description "Infrastructure haute disponibilité réalisée en BTS SIO SISR : pfSense et 4 VLAN, HAProxy (HTTP + SQL), cluster MariaDB Galera 3 nœuds, WordPress redondé, GLPI. Documentation, configurations anonymisées, scripts de validation et procédures de failover." \
  --add-topic bts-sio,sisr,proxmox,pfsense,haproxy,mariadb,galera,wordpress,glpi,linux,debian,high-availability,load-balancing,vlan,homelab,infrastructure
```

## Suite logique de commits

Pour un historique lisible qui raconte la construction du projet (alternative au commit unique initial) :

```bash
git add .gitignore .editorconfig .gitattributes LICENSE README.md SECURITY.md CONTRIBUTING.md CODE_OF_CONDUCT.md CHANGELOG.md
git commit -m "chore(repo): initialize BTS SIO HA infrastructure"

git add docs/00-overview docs/01-architecture docs/02-pfsense configs/pfsense diagrams/vlans.svg diagrams/architecture.svg
git commit -m "feat(network): document VLAN architecture"

git add docs/03-galera configs/galera scripts/install/install-galera.sh scripts/validation/check-galera.sh diagrams/galera-flow.svg
git commit -m "feat(galera): add three-node cluster configuration"

git add docs/04-haproxy configs/haproxy scripts/install/install-haproxy.sh scripts/validation/check-haproxy.sh scripts/utilities
git commit -m "feat(haproxy): add SQL and HTTP load balancing"

git add docs/05-wordpress configs/wordpress configs/apache/wordpress.conf.example scripts/install/install-wordpress-deps.sh scripts/validation/check-wordpress.sh diagrams/wordpress-flow.svg
git commit -m "feat(wordpress): add redundant web nodes"

git add docs/06-glpi configs/apache/glpi.conf.example scripts/install/install-glpi-deps.sh scripts/validation/check-glpi.sh
git commit -m "feat(glpi): add GLPI deployment"

git add docs/08-tests scripts/failover scripts/lib diagrams/failover-web.svg evidence
git commit -m "test(failover): document web failover validation"

git add docs/11-bts-sio docs/12-project-management deliverables examples
git commit -m "docs(bts): add BTS SIO technical documentation"

git add .
git update-index --chmod=+x scripts/install/*.sh scripts/validation/*.sh scripts/failover/*.sh scripts/backup/*.sh scripts/utilities/*.sh
git commit -m "chore(repo): add CI, security docs, generator and remaining documentation"
```

> Sous Linux/macOS, le bit exécutable est enregistré automatiquement par `git add` ; la commande `git update-index --chmod=+x` n'est indispensable que sous Windows.

## Branches et commits

Conventions : [CONTRIBUTING.md](../../CONTRIBUTING.md)

## Release

[release-v1.0.0.md](release-v1.0.0.md)
