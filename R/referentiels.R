# Lecture et validation des référentiels ------------------------------------------------------------
#
# Transposition de charger() de build_lca.py. Les référentiels sont lus dans <racine>/data ;
# les numéros 001 à N sont recalculés à partir de l'ordre de parcours.yml.

COUL  <- c(A = "#534AB7", B = "#0F6E56", C = "#993C1D", D = "#185FA5")
FOND  <- c(A = "#EEEDFE", B = "#E1F5EE", C = "#FAECE7", D = "#E6F1FB")
TEXTE <- c(A = "#26215C", B = "#04342C", C = "#4A1B0C", D = "#042C53")

lire_yaml <- function(racine, nom) {
  yaml::read_yaml(file.path(racine, "data", nom), fileEncoding = "UTF-8")
}

# Lit les cinq fichiers YAML sans contrôle.
lire_referentiels <- function(racine = ".") {
  list(
    cfg  = lire_yaml(racine, "config.yml"),
    lib  = lire_yaml(racine, "notions.yml"),
    cats = lire_yaml(racine, "categories.yml"),
    doms = lire_yaml(racine, "domaines.yml"),
    parc = lire_yaml(racine, "parcours.yml")
  )
}

# Contrôle les référentiels et construit l'index des notions.
# Renvoie list(erreurs = <character>, info = <list nommée par id>, ordre = <ids dans l'ordre du parcours>).
analyser_referentiels <- function(ref) {
  err <- character()
  ajouter <- function(...) err <<- c(err, paste0(...))
  lib <- ref$lib

  dom_num <- vapply(ref$doms, function(d) d$numero, numeric(1))
  cat_of_dom <- list()
  for (c in ref$cats) {
    for (d in c$domaines) {
      if (!is.null(cat_of_dom[[as.character(d)]])) ajouter("domaine ", d, " rattaché à deux catégories")
      cat_of_dom[[as.character(d)]] <- c$code
    }
  }
  diff_dom <- setdiff(union(names(cat_of_dom), dom_num), intersect(names(cat_of_dom), dom_num))
  if (length(diff_dom)) {
    ajouter("domaines sans catégorie ou inconnus : ", paste(diff_dom, collapse = ", "))
  }

  # notion -> domaine, niveau
  info <- list()
  for (d in ref$doms) {
    for (niv in c("base", "avance")) {
      for (i in unlist(d[[niv]])) {
        if (!is.null(info[[i]])) ajouter("notion ", i, " présente dans plusieurs domaines")
        if (is.null(lib[[i]])) ajouter("notion ", i, " (domaine ", d$numero, ") absente de notions.yml")
        info[[i]] <- list(domaine = d$numero, niveau = niv)
      }
    }
  }

  # parcours : numérotation, prérequis antérieurs, cohérence année/niveau
  ordre <- character()
  for (ph in ref$parc) {
    for (n in ph$notions) {
      i <- n$id
      if (i %in% ordre) {
        ajouter("notion ", i, " présente deux fois dans le parcours")
        next
      }
      if (is.null(info[[i]])) {
        ajouter("notion ", i, " du parcours absente de domaines.yml")
        next
      }
      pre <- as.character(unlist(n$prerequis))
      for (p in pre) {
        if (!p %in% ordre) ajouter(i, " : prérequis ", p, " inconnu ou placé après la notion")
      }
      if ((ph$annee == 1) != (info[[i]]$niveau == "base")) {
        ajouter(i, " : niveau ", info[[i]]$niveau, " incohérent avec l'année ", ph$annee)
      }
      ordre <- c(ordre, i)
      info[[i]] <- c(info[[i]], list(
        num = length(ordre), phase = ph$numero, annee = ph$annee, prerequis = pre
      ))
    }
  }
  manquants <- setdiff(names(info), ordre)
  if (length(manquants)) ajouter("notions absentes du parcours : ", paste(sort(manquants), collapse = ", "))
  orphelines <- setdiff(names(lib), names(info))
  if (length(orphelines)) ajouter("notions orphelines dans notions.yml : ", paste(sort(orphelines), collapse = ", "))

  if (length(err)) return(list(erreurs = err, info = NULL, ordre = NULL))

  for (i in ordre) {
    d <- as.character(info[[i]]$domaine)
    info[[i]]$libelle <- lib[[i]]
    info[[i]]$cat <- cat_of_dom[[d]]
    info[[i]]$code <- paste0(cat_of_dom[[d]], d)
    info[[i]]$dependants <- character()
  }
  for (i in ordre) {
    for (p in info[[i]]$prerequis) info[[p]]$dependants <- c(info[[p]]$dependants, i)
  }
  list(erreurs = character(), info = info[ordre], ordre = ordre)
}

# Lit, contrôle et arrête avec un message explicite en cas d'incohérence.
charger <- function(racine = ".") {
  ref <- lire_referentiels(racine)
  res <- analyser_referentiels(ref)
  if (length(res$erreurs)) {
    cli::cli_abort(c("Référentiels invalides :", stats::setNames(res$erreurs, rep("x", length(res$erreurs)))))
  }
  c(ref, res[c("info", "ordre")])
}

n3 <- function(info, i) sprintf("%03d", vapply(i, function(x) info[[x]]$num, numeric(1)))

ligne_parcours <- function(info, i) {
  x <- info[[i]]
  pre <- if (length(x$prerequis)) paste0(" ← ", paste(n3(info, x$prerequis), collapse = ", ")) else ""
  paste0(n3(info, i), ". ", x$libelle, " [", x$code, "]", pre)
}
