# Fiches récap -----------------------------------------------------------------------------------------
#
# Chaque fiches/<id>.md contient le corps seul ; l'en-tête est généré.
# [[id]] devient le numéro de la notion, [[id:libelle]] le numéro suivi du libellé.

MOTIF_RENVOI <- "\\[\\[([a-z0-9-]+)(:libelle)?\\]\\]"

remplacer_renvois <- function(corps, info, nom_fichier) {
  err <- character()
  m <- gregexpr(MOTIF_RENVOI, corps, perl = TRUE)
  regmatches(corps, m) <- lapply(regmatches(corps, m), function(trouves) {
    vapply(trouves, function(t) {
      ref <- sub(MOTIF_RENVOI, "\\1", t, perl = TRUE)
      if (is.null(info[[ref]])) {
        err <<- c(err, sprintf("fiche %s : renvoi [[%s]] inconnu", nom_fichier, ref))
        return(t)
      }
      if (grepl(":libelle", t, fixed = TRUE)) paste0(n3(info, ref), ". ", info[[ref]]$libelle) else n3(info, ref)
    }, character(1), USE.NAMES = FALSE)
  })
  list(corps = corps, erreurs = err)
}

# Renvoie list(fiches = <list(num, titre, html)> triée par numéro, erreurs = <character>).
analyser_fiches <- function(ref, racine = ".") {
  info <- ref$info
  fiches <- list()
  err <- character()
  liste <- function(ids) {
    if (!length(ids)) return("aucun")
    paste(vapply(ids, function(j) paste0(n3(info, j), ". ", info[[j]]$libelle), character(1)), collapse = " ; ")
  }
  for (fp in sort(list.files(file.path(racine, "fiches"), pattern = "\\.md$", full.names = TRUE))) {
    i <- tools::file_path_sans_ext(basename(fp))
    if (is.null(info[[i]])) {
      err <- c(err, sprintf("fiche %s : identifiant inconnu", basename(fp)))
      next
    }
    corps <- paste(readLines(fp, encoding = "UTF-8", warn = FALSE), collapse = "\n")
    r <- remplacer_renvois(corps, info, basename(fp))
    err <- c(err, r$erreurs)
    x <- info[[i]]
    tete <- paste0(
      "# ", n3(info, i), ". ", x$libelle, "\n\n",
      "Phase ", x$phase, " - [", x$code, "] - ", if (x$annee == 1) "Base" else "Avancé", "\n\n",
      "**Prérequis :** ", liste(x$prerequis), "\n\n",
      "**Ouvre vers :** ", liste(x$dependants), "\n\n"
    )
    rendu <- commonmark::markdown_html(paste0(tete, r$corps), extensions = "table")
    rendu <- gsub("<a href=", '<a target="_blank" rel="noopener" href=', rendu, fixed = TRUE)
    fiches[[length(fiches) + 1]] <- list(num = x$num, titre = paste0(n3(info, i), ". ", x$libelle), html = rendu)
  }
  fiches <- fiches[order(vapply(fiches, function(f) f$num, numeric(1)))]
  list(fiches = fiches, erreurs = err)
}

construire_fiches <- function(ref, racine = ".") {
  res <- analyser_fiches(ref, racine)
  if (length(res$erreurs)) {
    cli::cli_abort(c("Fiches invalides :", stats::setNames(res$erreurs, rep("x", length(res$erreurs)))))
  }
  res$fiches
}
