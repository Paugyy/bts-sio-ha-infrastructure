# Checklists avant publication et soutenance

## Checklist avant push / publication

### Sécurité

- [ ] Aucun mot de passe
- [ ] Aucune clé privée
- [ ] Aucune donnée sensible (export pfSense, sauvegarde, `wp-config.php` réel, `config_db.php`)
- [ ] Captures anonymisées (mots de passe, cookies, tokens masqués)
- [ ] `make check` sans échec

### Contenu

- [ ] README complet
- [ ] Architecture à jour (schémas et texte cohérents)
- [ ] IP cohérentes dans toute la documentation et les configurations
- [ ] Configs `.example` uniquement dans `configs/`
- [ ] Scripts testés sur les VM cibles
- [ ] Matrice de validation à jour (statuts honnêtes)

### Qualité

- [ ] Markdown lint OK (`make lint-md`)
- [ ] ShellCheck OK (`make lint-sh`)
- [ ] Liens OK (workflow *Links check*)

### Dépôt

- [ ] Licence présente
- [ ] SECURITY.md présent
- [ ] CHANGELOG présent et à jour
- [ ] Version taggée (`git tag -a v1.0.0`)

Commandes :

```bash
# SUR LE POSTE DE DÉVELOPPEMENT
make check && make lint
git status
git diff --cached | grep -Ein 'password|secret|token|BEGIN .*PRIVATE' || echo "OK : aucun motif suspect"
```

## Checklist soutenance BTS

- [ ] Objectif expliqué
- [ ] Architecture expliquée
- [ ] VLAN justifiés
- [ ] HA expliquée
- [ ] Galera expliqué
- [ ] Quorum expliqué
- [ ] HAProxy expliqué
- [ ] Failover démontré
- [ ] Incidents documentés
- [ ] Sécurité expliquée
- [ ] SPOF identifiés
- [ ] Améliorations proposées

### Préparation technique le jour J

- [ ] Toutes les VM démarrées, `check-galera.sh` OK sur les 3 nœuds
- [ ] `check-wordpress.sh` et `check-glpi.sh` OK
- [ ] Snapshot Proxmox récent
- [ ] Deux terminaux SSH ouverts sur ADM-01, page de stats HAProxy ouverte
- [ ] Captures et sorties de secours disponibles hors ligne ([evidence/](../../evidence/README.md), [deliverables/](../../deliverables/README.md))
