#!/usr/bin/env Rscript
# Boussole LCA - génération des livrables à partir des référentiels.
#
# Usage : Rscript build.R
#
# Sorties dans _output/ :
#   lca_notions_parcours.html   page unique à quatre onglets, utilisable hors ligne (Quarto)
#   reseau_lca.pdf              réseau de dépendances
#   boussole_lca_notions.json   mapping des notions pour le skill de création de sujets de LCA

source("R/charger_tout.R", encoding = "UTF-8")

sortie <- "_output"

# 1. Contrôles : arrêt avec message explicite en cas d'incohérence
ref <- charger()
fiches <- construire_fiches(ref)
testthat::test_dir("tests/testthat", reporter = "summary", stop_on_failure = TRUE)

# 2. Page HTML
quarto::quarto_render("index.qmd", quiet = TRUE)

# 3. Réseau en PDF et mapping JSON (après le rendu Quarto, qui gère lui-même le dossier de sortie)
dir.create(sortie, showWarnings = FALSE)
exporter_reseau(ref, sortie)
exporter_mapping(ref, fiches, sortie)

nb_base <- sum(vapply(ref$info, function(x) x$niveau == "base", logical(1)))
cli::cli_alert_success(paste(
  "{length(ref$info)} notions ({nb_base} base, {length(ref$info) - nb_base} avancées),",
  "{length(ref$parc)} phases, {sum(lengths(lapply(ref$info, `[[`, 'prerequis')))} dépendances,",
  "{length(fiches)} fiches -> {.path {sortie}}"
))
