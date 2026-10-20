RACINE <- normalizePath(file.path(testthat::test_path(), "..", ".."))
withr::with_envvar(c(BOUSSOLE_RACINE = RACINE), source(file.path(RACINE, "R", "charger_tout.R"), encoding = "UTF-8"))

ref_reel <- function() lire_referentiels(RACINE)

# Applique une modification au référentiel réel et renvoie les erreurs détectées.
erreurs_apres <- function(modifier) {
  ref <- modifier(ref_reel())
  analyser_referentiels(ref)$erreurs
}

# Position (phase, rang) d'une notion dans parcours.yml.
position <- function(ref, id) {
  for (k in seq_along(ref$parc)) {
    for (r in seq_along(ref$parc[[k]]$notions)) {
      if (ref$parc[[k]]$notions[[r]]$id == id) return(c(k, r))
    }
  }
  stop("notion absente : ", id)
}

# Copie data/ et fiches/ dans un dossier temporaire (supprimé à la fin du test appelant).
racine_temporaire <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  file.copy(file.path(RACINE, c("data", "fiches", "assets")), dir, recursive = TRUE)
  dir
}
