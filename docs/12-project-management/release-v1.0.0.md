# Release v1.0.0

## Création

```bash
# SUR LE POSTE DE DÉVELOPPEMENT — depuis main à jour, CI verte
git tag -a v1.0.0 -m "BTS SIO HA Infrastructure — Initial Release"
git push origin v1.0.0

# Release GitHub avec ces notes (section ci-dessous copiée dans un fichier)
gh release create v1.0.0 --title "BTS SIO HA Infrastructure — Initial Release" --notes-file release-notes.md
```

### Assets optionnels

| Asset | Source | Remarque |
|-------|--------|----------|
| Livrable HTML | `deliverables/html/` | Version autonome de la documentation de soutenance |
| PDF | `deliverables/pdf/` | Dossier de soutenance |
| Générateur | `generator/` zippé | `zip -r generator-v1.0.0.zip generator/` |

**Jamais** : sauvegardes, exports pfSense, configurations réelles, captures non anonymisées.

```bash
gh release upload v1.0.0 generator-v1.0.0.zip deliverables/pdf/<FICHIER>.pdf
```

---

## Notes de version

### BTS SIO HA Infrastructure — Initial Release

Première version publique de l'infrastructure haute disponibilité réalisée en BTS SIO option SISR.

#### Architecture

- pfSense : WAN `10.4.0.198/24`, 4 VLAN (301 vWEB, 302 vBDD, 303 vADMIN, 304 vUSER), filtrage deny-by-default.
- NAT `WAN:8081 → HAProxy 10.0.10.2:80`.
- HAProxy `10.0.10.2` : WordPress (`:80`), GLPI (`:8080`), SQL (`:3306`), statistiques (`:8404`, vADMIN).
- WordPress sur WEB-01 (`10.0.10.1`) et WEB-02 (`10.0.10.4`), health-check applicatif, persistance par cookie.
- MariaDB 10.11 + Galera 4, cluster `mon_cluster_galera` sur MYSQL-01/02/03 (`10.0.20.1-3`).
- GLPI 10 sur GLPI-01 (`10.0.10.3`).

#### Contenu du dépôt

- 13 sections de documentation (vue d'ensemble → gestion de projet), chaque commande indiquant sa VM cible.
- Configurations anonymisées : HAProxy, Galera (3 nœuds), Apache (WordPress, GLPI), `wp-config.php`, SSH, règles pfSense.
- Scripts : installation (simulation par défaut), validation, failover guidé, sauvegarde, utilitaires.
- Générateur HTML hors ligne pour produire une infrastructure équivalente avec d'autres paramètres.
- 6 schémas SVG.
- CI : markdownlint, ShellCheck, validation des configurations (dont `haproxy -c` et `php -l`), liens.
- 8 incidents réels documentés.

#### Tests

Matrice de 20 tests (T01 à T20) : voir `docs/08-tests/validation-matrix.md` pour le statut réel de chaque test et ses preuves.

#### Limites connues

- SPOF : HAProxy, pfSense, GLPI, hôte Proxmox.
- Health-check SQL non wsrep-aware.
- Fichiers WordPress synchronisés par rsync.
- HTTP uniquement.

#### Prochaines étapes

HAProxy secondaire + Keepalived, health-check Galera wsrep-aware, sauvegardes automatisées, HTTPS, supervision.
