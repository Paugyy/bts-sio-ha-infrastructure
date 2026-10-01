# GLPI — Installation

## Fiche

| Élément | Valeur |
|---------|--------|
| VM | GLPI-01 |
| IP | 10.0.10.3/24, passerelle 10.0.10.254 |
| VLAN | 301 — vWEB |
| OS | Debian 12 |
| Logiciels | Apache 2.4, PHP 8.2, GLPI 10.x |
| Racine | `/var/www/glpi` — **DocumentRoot** `/var/www/glpi/public` |
| Base | `glpi` via `10.0.10.2:3306` (HAProxy → Galera) |
| Publication | `http://10.0.10.2:8080/` |
| Redondance | **Aucune** (SPOF assumé, voir [spof-analysis.md](../01-architecture/spof-analysis.md)) |

## 1. Dépendances

**SUR GLPI-01**

```bash
sudo ./scripts/install/install-glpi-deps.sh            # simulation
sudo ./scripts/install/install-glpi-deps.sh --apply
```

## 2. Téléchargement de GLPI

Récupérer l'archive de la **dernière version stable 10.x** sur la page officielle des releases (`github.com/glpi-project/glpi/releases`) et noter son empreinte publiée.

**SUR GLPI-01**

```bash
cd /tmp
wget https://github.com/glpi-project/glpi/releases/download/<VERSION>/glpi-<VERSION>.tgz
sha256sum glpi-<VERSION>.tgz          # comparer avec l'empreinte publiée
sudo tar -xzf glpi-<VERSION>.tgz -C /var/www/
sudo chown -R www-data:www-data /var/www/glpi
```

## 3. Base de données

Voir [database.md](database.md) : base `glpi`, compte `glpi`@`10.0.10.2`.

## 4. Apache

Voir [apache.md](apache.md) : vhost avec `DocumentRoot /var/www/glpi/public` et réécritures.

## 5. Assistant d'installation

**SUR ADM-01** (navigateur) : `http://10.0.10.3/`

| Écran | Valeur |
|-------|--------|
| Serveur SQL | `10.0.10.2` (HAProxy) — port 3306 par défaut |
| Utilisateur SQL | `glpi` |
| Mot de passe SQL | `<PASSWORD>` |
| Base | `glpi` (existante) |

L'assistant vérifie les prérequis PHP : tout doit être vert (les avertissements de sécurité sont traités ci-dessous).

## 6. Après l'installation (obligatoire)

**SUR ADM-01** (interface GLPI)

- Changer les mots de passe des comptes par défaut `glpi`, `tech`, `normal`, `post-only` (ou désactiver ceux qui sont inutiles).

**SUR GLPI-01**

```bash
sudo rm /var/www/glpi/install/install.php
```

## 7. Vérification

```bash
# SUR ADM-01
./scripts/validation/check-glpi.sh
```

Capture attendue : `evidence/screenshots/10-glpi.png`
