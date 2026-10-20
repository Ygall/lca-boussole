# Boussole LCA

Parcours structuré d'apprentissage de la lecture critique d'article (LCA) pour les étudiants de DFASM.
Dr. Yves Gallien, Université de Rennes.

Proposition pédagogique : ce document ne constitue pas un programme officiel de LCA.

## Génération

Prérequis : Python 3.9 ou plus, Graphviz (exécutable `dot` dans le PATH).

```
python -m venv .venv
source .venv/bin/activate          # Windows : .venv\Scripts\activate
pip install -r requirements.txt
python build_lca.py                # sorties dans dist/
```

Sorties : `lca_notions_parcours.html` (page unique, quatre onglets, hors ligne), cartes mentales
`.md` (Markmap) et `.mm` (Freeplane), réseau de dépendances `.dot`, `.svg`, `.pdf`.

## Organisation

| Chemin | Contenu |
|---|---|
| `data/config.yml` | Titre, auteur, version, date, avertissement |
| `data/notions.yml` | Libellé de chaque notion, indexé par identifiant stable |
| `data/categories.yml` | Catégories A à D et domaines rattachés |
| `data/domaines.yml` | Notions de base et avancées de chaque domaine (ordre de la carte des notions) |
| `data/parcours.yml` | Phases ordonnées, notions et prérequis directs (ordre du parcours) |
| `fiches/<identifiant>.md` | Corps des fiches récap ; l'en-tête est généré |
| `vendor/` | d3 7.9.0 (ISC) et markmap-view 0.17.2 (MIT), intégrés au HTML |
| `build_lca.py` | Contrôles de cohérence et génération |

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
d'un domaine ou du parcours, prérequis placé après la notion, incohérence entre niveau et année,
fiche ou renvoi vers une notion inexistante.
