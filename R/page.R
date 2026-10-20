# Page HTML : corps (assets/gabarit.html) et données injectées pour assets/app.js ---------------------

# Remplace {{CLE}} par la valeur, sans interprétation des caractères spéciaux.
remplir <- function(gabarit, valeurs) {
  for (cle in names(valeurs)) {
    morceaux <- strsplit(gabarit, paste0("{{", cle, "}}"), fixed = TRUE)[[1]]
    if (endsWith(gabarit, paste0("{{", cle, "}}"))) morceaux <- c(morceaux, "")
    gabarit <- paste(morceaux, collapse = as.character(valeurs[[cle]]))
  }
  restants <- regmatches(gabarit, gregexpr("\\{\\{[A-Z_]+\\}\\}", gabarit))[[1]]
  if (length(restants)) cli::cli_abort("Gabarit : champs non remplis {.val {restants}}")
  gabarit
}

corps_html <- function(ref, svg, racine = ".") {
  cfg <- ref$cfg
  gabarit <- paste(readLines(file.path(racine, "assets", "gabarit.html"), encoding = "UTF-8", warn = FALSE), collapse = "\n")
  remplir(gabarit, list(
    TITRE = esc_html(cfg$titre),
    N = length(ref$info),
    NB_CATS = length(ref$cats),
    NB_DOMS = length(ref$doms),
    NB_PHASES = length(ref$parc),
    SVG = svg,
    PROJET = esc_html(cfg$projet),
    AUTEUR = esc_html(cfg$auteur),
    AFFILIATION = esc_html(cfg$affiliation),
    VERSION = esc_html(as.character(cfg$version)),
    DATE = esc_html(as.character(cfg$date)),
    AVERTISSEMENT = esc_html(cfg$avertissement)
  ))
}

vers_json <- function(x) {
  j <- jsonlite::toJSON(x, auto_unbox = TRUE, null = "null")
  gsub("</", "<\\/", j, fixed = TRUE) # pas de </script> prématuré
}

donnees_js <- function(ref, fiches) {
  info <- ref$info
  phases <- lapply(ref$parc, function(ph) {
    ids <- vapply(ph$notions, function(n) n$id, character(1))
    list(k = ph$numero, l = sprintf("Phase %s. %s", ph$numero, ph$titre), an = sprintf("Année %s", ph$annee),
         ids = I(paste0("n", n3(info, ids))))
  })
  pdata <- lapply(ref$ordre, function(i) {
    x <- info[[i]]
    list(num = n3(info, i), t = x$libelle, c = x$code, p = x$phase, lvl = if (x$annee == 1) "base" else "avancé")
  })
  names(pdata) <- paste0("n", n3(info, ref$ordre))
  paste0(
    "const MM=", vers_json(arbre_notions(ref)), ";\n",
    "const PM=", vers_json(arbre_parcours(ref)), ";\n",
    "const PD=", vers_json(pdata), ";\n",
    "const PH=", vers_json(phases), ";\n",
    "const FI=", vers_json(fiches), ";\n"
  )
}
