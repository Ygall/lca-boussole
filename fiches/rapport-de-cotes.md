## Message clé

Le rapport de cotes (*odds ratio*, OR) compare la cote d'un événement entre deux groupes. Il est utilisable dans tous les schémas, c'est la seule mesure d'association estimable en cas-témoins ([[rapport-de-cotes-seule-mesure-estimable]]) et c'est la mesure produite par la régression logistique ([[regressions-lineaire-logistique-cox]]).

## À retenir

- Cote = p / (1 - p), soit le nombre de « oui » rapporté au nombre de « non ». Un risque de 20 % correspond à une cote de 0,25.

Tableau 2 x 2 :

|               | Malades | Non malades |
|---------------|---------|-------------|
| Exposés       | a       | b           |
| Non exposés   | c       | d           |


OR = (a / b) / (c / d) = (a x d) / (b x c).

- Interprétation : OR = 1, absence d'association ; OR > 1, association positive ; OR < 1, association négative. L'association est statistiquement significative si l'IC à 95 % exclut 1.
- Lorsque RR est différent de 1, l'OR est toujours plus éloigné de 1 que le RR, et l'écart augmente avec la fréquence de l'événement.
- L'OR est symétrique : l'OR d'exposition (cas vs témoins) est égal à l'OR de maladie (exposés vs non exposés). C'est ce qui justifie son emploi en cas-témoins.
- Un OR ajusté (*adjusted OR*) provient d'une régression logistique et tient compte des facteurs de confusion inclus dans le modèle ([[facteur-de-confusion]], [[ajustement]]).

## Pièges en QCM

- « OR = 2,5 : les exposés ont un risque 2,5 fois plus élevé » : formulation inexacte, l'OR compare des cotes et surestime l'association par rapport au RR quand l'événement est fréquent.
- « OR = 0,60 : réduction du risque de 40 % » : inexact pour la même raison.
- « Dans cette étude cas-témoins, le RR est de 1,8 » : faux, ni l'incidence ni le RR ne sont estimables en cas-témoins ([[impossibilite-d-estimer-incidence-et-prevalence]]).
- OR = 1,7 (IC 95 % : 0,9 - 3,1) : association non significative, l'IC contient 1.

## Repérage dans l'article

Résultats et tableaux : *odds ratio, 2.1; 95% CI, 1.4 to 3.2*, *adjusted odds ratio (aOR)*. En Méthodes, la mention d'une *logistic regression* annonce des OR.

## Référence

Davies HT, Crombie IK, Tavakoli M. When can odds ratios mislead? BMJ 1998;316:989-91. [DOI](https://doi.org/10.1136/bmj.316.7136.989)
