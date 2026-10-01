# Labels GitHub

| Label | Couleur | Usage |
|-------|---------|-------|
| `documentation` | `0075ca` | Documentation |
| `network` | `1d76db` | VLAN, routage, adressage |
| `pfsense` | `212121` | Pare-feu, NAT |
| `galera` | `003545` | Cluster MariaDB |
| `haproxy` | `106da9` | Répartiteur |
| `wordpress` | `21759b` | WEB-01, WEB-02 |
| `glpi` | `f39c12` | GLPI |
| `security` | `b60205` | Sécurité, secrets, durcissement |
| `testing` | `0e8a16` | Tests, matrice, preuves |
| `bug` | `d73a4a` | Dysfonctionnement |
| `enhancement` | `a2eeef` | Amélioration |
| `bts-sio` | `6f42c1` | Livrables et préparation de l'épreuve |
| `high-availability` | `5319e7` | Redondance, failover, SPOF |
| `chore` | `cfd3d7` | Maintenance du dépôt (utilisé par Dependabot) |

## Création avec GitHub CLI

```bash
# SUR LE POSTE DE DÉVELOPPEMENT (gh auth login préalable)
while IFS='|' read -r name color desc; do
  gh label create "$name" --color "$color" --description "$desc" --force
done <<'EOF'
documentation|0075ca|Documentation
network|1d76db|VLAN, routage, adressage
pfsense|212121|Pare-feu, NAT
galera|003545|Cluster MariaDB Galera
haproxy|106da9|Répartiteur HAProxy
wordpress|21759b|WEB-01, WEB-02
glpi|f39c12|GLPI
security|b60205|Sécurité, secrets, durcissement
testing|0e8a16|Tests, matrice, preuves
bug|d73a4a|Dysfonctionnement
enhancement|a2eeef|Amélioration
bts-sio|6f42c1|Livrables et épreuve BTS SIO
high-availability|5319e7|Redondance, failover, SPOF
chore|cfd3d7|Maintenance du dépôt
EOF
```
