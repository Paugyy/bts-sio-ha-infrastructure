# Livrables de soutenance

Ce dossier accueille les **livrables de soutenance** du projet, produits à partir de la documentation du dépôt.

```text
deliverables/
├── html/   version HTML autonome (consultable hors ligne le jour de l'épreuve)
└── pdf/    dossier de soutenance et support de présentation au format PDF
```

## Contenu attendu

| Livrable | Format | Source |
|----------|--------|--------|
| Dossier technique | PDF | `docs/` (vue d'ensemble, architecture, tests, incidents) |
| Support de présentation | PDF | [oral-presentation.md](../docs/11-bts-sio/oral-presentation.md) |
| Documentation consultable | HTML | `docs/` + `diagrams/` + [generator/](../generator/README.md) |
| Fiche de synthèse | PDF | Section *Fiche portfolio* du [README](../README.md#fiche-portfolio) |

## Produire un PDF à partir du Markdown (exemple)

```bash
# SUR LE POSTE DE DÉVELOPPEMENT — nécessite pandoc et un moteur LaTeX
pandoc docs/00-overview/project-context.md docs/01-architecture/*.md \
  -o deliverables/pdf/dossier-technique.pdf --toc -V lang=fr
```

## Règles

- Les livrables sont des **copies** : la référence reste la documentation Markdown du dépôt.
- Relire chaque livrable avec la [checklist avant publication](../docs/11-bts-sio/pre-publish-checklist.md) : aucun secret, captures anonymisées.
- Les livrables peuvent être joints à la release GitHub (voir [release-v1.0.0.md](../docs/12-project-management/release-v1.0.0.md)).
- Fichiers volumineux (> 50 Mo) : à publier comme *assets* de release plutôt que dans l'historique Git.
