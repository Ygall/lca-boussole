#!/usr/bin/env Rscript
# Boussole LCA - génération des livrables à partir des référentiels.
#
# Usage : Rscript build.R
#
# Sorties dans _output/ :
#   lca_notions_parcours.html   page unique à quatre onglets, utilisable hors ligne (Quarto)
#   carte_mentale_lca.md/.mm    carte des notions (Markmap / Freeplane)
#   parcours_lca.md/.mm         parcours ordonné avec prérequis (Markmap / Freeplane)
#   reseau_lca.dot/.svg/.pdf    réseau de dépendances

source("R/charger_tout.R", encoding = "UTF-8")

sortie <- "_output"

# 1. Contrôles : arrêt avec message explicite en cas d'incohérence
ref <- charger()
fiches <- construire_fiches(ref)

# 2. Page HTML
quarto::quarto_render("index.qmd", quiet = TRUE)

# 3. Exports annexes (après le rendu Quarto, qui gère lui-même le dossier de sortie)
dir.create(sortie, showWarnings = FALSE)
exporter_cartes(ref, sortie)
invisible(exporter_reseau(ref, sortie))

nb_base <- sum(vapply(ref$info, function(x) x$annee == 1, logical(1)))
cli::cli_alert_success(paste(
  "{length(ref$info)} notions ({nb_base} base, {length(ref$info) - nb_base} avancées),",
  "{length(ref$parc)} phases, {sum(lengths(lapply(ref$info, `[[`, 'prerequis')))} dépendances,",
  "{length(fiches)} fiches -> {.path {sortie}}"
))
