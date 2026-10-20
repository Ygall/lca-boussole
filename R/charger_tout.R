# Charge toutes les fonctions du dossier R/ (racine du projet : variable BOUSSOLE_RACINE, défaut ".").
local({
  dossier <- file.path(Sys.getenv("BOUSSOLE_RACINE", "."), "R")
  for (f in list.files(dossier, pattern = "\\.R$", full.names = TRUE)) {
    if (basename(f) != "charger_tout.R") source(f, encoding = "UTF-8")
  }
})
