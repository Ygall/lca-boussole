# Boussole LCA

Parcours structuré d'apprentissage de la lecture critique d'article (LCA) pour les étudiants de DFASM.
Dr. Yves Gallien, Université de Rennes.

Proposition pédagogique : ce document ne constitue pas un programme officiel de LCA.

## Génération

Prérequis : R ≥ 4.5 et [Quarto](https://quarto.org) ≥ 1.5. Graphviz n'est pas nécessaire
(le réseau est rendu par viz.js via DiagrammeRsvg).

```r
renv::restore()        # installe les versions figées dans renv.lock (première fois)
```

```bash
Rscript build.R        # contrôles + tests + génération, sorties dans _output/
```

Sorties : `lca_notions_parcours.html` (page unique, quatre onglets, hors ligne), cartes mentales
`.md` (Markmap) et `.mm` (Freeplane), réseau de dépendances `.dot`, `.svg`, `.pdf`.

Tests seuls : `Rscript -e "testthat::test_dir('tests/testthat')"`.

## Organisation

| Chemin | Contenu |
|---|---|
| `data/config.yml` | Titre, auteur, version, date, avertissement |
| `data/notions.yml` | Libellé de chaque notion, indexé par identifiant stable |
| `data/categories.yml` | Catégories A à D et domaines rattachés |
| `data/domaines.yml` | Notions de base et avancées de chaque domaine (ordre de la carte des notions) |
| `data/parcours.yml` | Phases ordonnées, notions et prérequis directs (ordre du parcours) |
| `fiches/<identifiant>.md` | Corps des fiches récap ; l'en-tête est généré |
| `R/` | Lecture et contrôle des référentiels, cartes, réseau, fiches, page |
| `index.qmd`, `_quarto.yml` | Page Quarto (HTML autonome, `embed-resources`) |
| `assets/` | Gabarit HTML, CSS et JavaScript de la page |
| `vendor/` | d3 7.9.0 (ISC) et markmap-view 0.17.2 (MIT), intégrés au HTML |
| `tests/testthat/` | Contrôles de cohérence et de non-régression |
| `build.R` | Point d'entrée de la génération |
| `legacy/` | Générateur Python d'origine (`build_lca.py`), conservé pour référence |

## Règles d'édition

- Un identifiant de notion ne change jamais. Les numéros 001 à N sont recalculés à chaque génération
  à partir de l'ordre de `parcours.yml`.
- Ajouter une notion : libellé dans `notions.yml`, rattachement dans `domaines.yml`, position et
  prérequis dans `parcours.yml`.
- Les notions de base sont placées en année 1, les notions avancées en année 2.
- Dans une fiche, `[[identifiant]]` devient le numéro de la notion et `[[identifiant:libelle]]` le
  numéro suivi du libellé. Les sections attendues sont : Message clé, À retenir, Pièges en QCM,
  Repérage dans l'article, Référence.

La génération s'arrête avec un message explicite si : identifiant dupliqué ou inconnu, notion absente
d'un domaine ou du parcours, prérequis placé après la notion (ce qui exclut aussi tout cycle),
incohérence entre niveau et année, fiche ou renvoi vers une notion inexistante.

## Versions

Une version par année universitaire (étiquette git `vAAAA.N`, voir `CHANGELOG.md`) ; la version
affichée dans la page est lue dans `data/config.yml`.

## Licence

Code : MIT (`LICENSE`). Contenus pédagogiques (`data/`, `fiches/`) : licence à arrêter avec
l'Université de Rennes.
