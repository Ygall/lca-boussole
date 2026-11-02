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

Sorties :

| Fichier | Usage |
|---|---|
| `lca_notions_parcours.html` | Page unique à quatre onglets, utilisable hors ligne (diffusion aux étudiants) |
| `reseau_lca.pdf` | Réseau des dépendances, pour impression |
| `boussole_lca_notions.json` | Mapping des notions pour le skill de création de sujets de LCA (voir plus bas) |

Sous RStudio, ouvrir `lca-boussole.Rproj` (renv s'active automatiquement), puis `source("build.R")`.

Tests seuls : `Rscript -e "testthat::test_dir('tests/testthat')"`.

## Organisation

| Chemin | Contenu |
|---|---|
| `data/config.yml` | Titre, auteur, version, date, avertissement |
| `data/notions.yml` | Libellé, description et termes anglais de chaque notion, indexés par identifiant stable |
| `data/categories.yml` | Catégories A à D et domaines rattachés |
| `data/domaines.yml` | Notions de base et avancées de chaque domaine (ordre de la carte des notions) |
| `data/parcours.yml` | Phases ordonnées et leur niveau, notions et prérequis directs (ordre du parcours) |
| `fiches/<identifiant>.md` | Corps des fiches récap ; l'en-tête est généré |
| `R/` | Lecture et contrôle des référentiels, cartes, réseau, fiches, page, mapping |
| `index.qmd`, `_quarto.yml` | Page Quarto (HTML autonome, `embed-resources`) |
| `assets/` | Gabarit HTML, CSS et JavaScript de la page |
| `vendor/` | d3 7.9.0 (ISC) et markmap-view 0.17.2 (MIT), intégrés au HTML |
| `tests/testthat/` | Contrôles de cohérence et de non-régression |
| `build.R` | Point d'entrée de la génération |
| `lca-boussole.Rproj` | Projet RStudio |

## Règles d'édition

- Un identifiant de notion ne change jamais. Les numéros 001 à N sont recalculés à chaque génération
  à partir de l'ordre de `parcours.yml`.
- Ajouter une notion : libellé, description (une phrase) et termes anglais dans `notions.yml`,
  rattachement dans `domaines.yml`, position et prérequis dans `parcours.yml`.
- Chaque notion est de niveau base ou avancé (défini dans `domaines.yml`) et se place dans une phase
  du même niveau ; les phases de base précèdent les phases avancées.
- Dans une fiche, `[[identifiant]]` devient le numéro de la notion et `[[identifiant:libelle]]` le
  numéro suivi du libellé. Les sections attendues sont : Message clé, À retenir, Pièges en QCM,
  Repérage dans l'article, Référence.

La génération s'arrête avec un message explicite si : identifiant dupliqué ou inconnu, notion absente
d'un domaine ou du parcours, prérequis placé après la notion (ce qui exclut aussi tout cycle),
niveau de la notion différent de celui de sa phase, phase de base placée après une phase avancée,
libellé ou description manquant, fiche ou renvoi vers une notion inexistante.

## Mapping pour le skill de création de sujets

`boussole_lca_notions.json` est un fichier JSON autonome destiné à être copié dans le skill de
création de sujets de LCA, pour indexer chaque question sur les notions qu'elle mobilise.

- En-tête : `format`, `version_format` (structure du fichier), `version` et `date_version` du mapping
  (lues dans `data/config.yml`), `genere_le`, `commit` git (suffixe `-modifie` si `data/` ou
  `fiches/` n'étaient pas commités), avertissement et consignes d'usage.
- `categories`, `domaines`, `phases` : structure du référentiel.
- `notions` : pour chacune, `id` stable, `numero`, `libelle`, `description`, `niveau` (`base` ou
  `avance`), `categorie`, `domaine`, `code` (ex. `B7`), `phase`, `prerequis` et `ouvre_vers`
  (identifiant et numéro), `termes_en` et présence d'une `fiche`.

Le skill doit référencer les notions par `id` : les numéros changent dès qu'une notion est ajoutée
ou déplacée dans le parcours.

## Versions

Une version par rentrée universitaire (étiquette git `vAAAA.N`, voir `CHANGELOG.md`) ; la version
affichée dans la page et inscrite dans le mapping est lue dans `data/config.yml`.

## Licence

Code : MIT (`LICENSE`). Contenus pédagogiques (`data/`, `fiches/`) : licence à arrêter avec
l'Université de Rennes.
