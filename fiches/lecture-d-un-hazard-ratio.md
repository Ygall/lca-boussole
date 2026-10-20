## Message clé

Le hazard ratio (HR) compare la vitesse de survenue d'un événement entre deux groupes sur toute la durée du suivi. Il rapporte les risques instantanés des deux groupes, suppose ce rapport constant dans le temps et est estimé par un modèle de Cox.

## À retenir

- Le risque instantané (*hazard*) est la probabilité de survenue de l'événement dans un intervalle de temps très court, chez les sujets encore à risque à ce moment.
- HR = risque instantané du groupe expérimental / risque instantané du groupe de référence. Le groupe de référence doit être vérifié dans l'article, car il détermine le sens de lecture.
- HR = 1 : absence de différence. HR = 0,75 : à tout instant du suivi, le risque instantané est réduit de 25 % dans le groupe expérimental (réduction relative).
- Le HR est significatif si son IC à 95 % exclut 1. Sa conclusion est en règle générale concordante avec celle du test du log-rank ([[test-du-log-rank]]).
- Le HR intègre le délai de survenue et la censure, alors qu'un RR compare des proportions d'événements à une date donnée.
- Le HR est une mesure relative. L'effet absolu se lit sur les courbes de Kaplan-Meier à un temps donné (différence de proportions, NNT à ce temps).
- Le HR repose sur l'hypothèse des risques proportionnels ([[hypothese-des-risques-proportionnels]]). Les courbes de Kaplan-Meier s'écartent alors progressivement sans se croiser. Si elles se croisent, un HR unique résume mal l'effet.
- Pour un critère de mortalité, HR < 1 correspond à une courbe de survie du groupe expérimental située au-dessus de celle du groupe de référence, ou à une courbe d'incidence cumulée située en dessous.
- Un HR ajusté provient d'un modèle de Cox multivarié ([[regressions-lineaire-logistique-cox]]).

## Pièges en QCM

- « HR = 0,75 : 25 % de patients en moins ont présenté l'événement » : faux, le HR ne compare pas des proportions cumulées.
- « HR = 0,75 : la durée de survie est allongée de 25 % » ou « la médiane de survie est augmentée de 25 % » : faux, le HR ne compare pas des durées.
- « HR et RR sont deux noms de la même mesure » : faux.
- HR = 0,88 (IC 95 % : 0,76 - 1,02) : non significatif, l'IC contient 1.
- Courbes de Kaplan-Meier qui se croisent : l'interprétation d'un HR global est discutable, y compris lorsqu'il est non significatif.

## Repérage dans l'article

Résumé et Résultats : *hazard ratio, 0.75; 95% CI, 0.62 to 0.91; P=0.003*. Méthodes : *Cox proportional-hazards model*, et vérification éventuelle de l'hypothèse de proportionnalité (*Schoenfeld residuals*). Figure : courbes de Kaplan-Meier avec le HR souvent reporté sur le graphique et le nombre de sujets à risque sous l'axe des abscisses.

## Référence

Spruance SL, Reid JE, Grace M, Samore M. Hazard ratio in clinical trials. Antimicrob Agents Chemother 2004;48:2787-92. [DOI](https://doi.org/10.1128/AAC.48.8.2787-2792.2004)
