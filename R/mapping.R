# Mapping des notions pour les outils externes (skill de création de sujets de LCA) -----------------
#
# Un fichier JSON autonome : version du mapping, structure (catégories, domaines, phases) et, pour
# chaque notion, identifiant stable, numéro, libellé, description, niveau, rattachements, prérequis,
# notions dépendantes et termes anglais. Les outils doivent référencer les notions par `id`.

FORMAT_MAPPING <- "boussole-lca/mapping-notions"
VERSION_FORMAT_MAPPING <- 1L

commit_git <- function(racine = ".") {
  hash <- tryCatch(
    suppressWarnings(system2("git", c("-C", shQuote(racine), "rev-parse", "--short", "HEAD"), stdout = TRUE, stderr = FALSE)),
    error = function(e) character()
  )
  if (!length(hash) || !nzchar(hash[1])) return(NA_character_)
  etat <- tryCatch(
    suppressWarnings(system2("git", c("-C", shQuote(racine), "status", "--porcelain", "--", "data", "fiches"), stdout = TRUE, stderr = FALSE)),
    error = function(e) character()
  )
  if (length(etat)) paste0(hash[1], "-modifie") else hash[1]
}

mapping_notions <- function(ref, fiches, racine = ".") {
  info <- ref$info
  cfg <- ref$cfg
  avec_fiche <- tools::file_path_sans_ext(list.files(file.path(racine, "fiches"), pattern = "\\.md$"))
  dom_cat <- unlist(lapply(ref$cats, function(c) stats::setNames(rep(c$code, length(c$domaines)), c$domaines)))
  ids_num <- function(ids) lapply(as.character(ids), function(j) list(id = j, numero = n3(info, j)))

  list(
    format = FORMAT_MAPPING,
    version_format = VERSION_FORMAT_MAPPING,
    projet = cfg$projet,
    version = as.character(cfg$version),
    date_version = as.character(cfg$date),
    genere_le = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    commit = commit_git(racine),
    auteur = paste0(cfg$auteur, ", ", cfg$affiliation),
    avertissement = cfg$avertissement,
    consignes = c(
      "Référencer une notion par son `id`, qui est stable d'une version à l'autre ; le `numero` est recalculé à chaque version selon l'ordre du parcours.",
      "`niveau` vaut `base` (repérer une information et lire un résultat) ou `avance` (juger un choix méthodologique, repérer une limite non déclarée).",
      "`prerequis` liste les notions à maîtriser avant ; `ouvre_vers` les notions qui s'appuient sur celle-ci.",
      "`termes_en` donne des formulations anglaises fréquentes pour repérer la notion dans un article ; la liste n'est pas exhaustive.",
      "Signaler la version du mapping (`version`, `commit`) dans tout document produit à partir de ce fichier."
    ),
    effectifs = list(
      notions = length(info),
      base = sum(vapply(info, function(x) x$niveau == "base", logical(1))),
      avance = sum(vapply(info, function(x) x$niveau == "avance", logical(1))),
      fiches = length(fiches)
    ),
    categories = lapply(ref$cats, function(c) list(code = c$code, libelle = c$libelle, domaines = I(as.integer(c$domaines)))),
    domaines = lapply(ref$doms, function(d) {
      list(numero = as.integer(d$numero), code = paste0(dom_cat[[as.character(d$numero)]], d$numero),
           libelle = d$libelle, categorie = dom_cat[[as.character(d$numero)]])
    }),
    phases = lapply(ref$parc, function(ph) {
      list(numero = as.integer(ph$numero), titre = ph$titre, niveau = ph$niveau,
           notions = I(vapply(ph$notions, function(n) n$id, character(1))))
    }),
    notions = lapply(ref$ordre, function(i) {
      x <- info[[i]]
      list(
        id = i,
        numero = n3(info, i),
        libelle = x$libelle,
        description = x$description,
        niveau = x$niveau,
        categorie = x$cat,
        domaine = as.integer(x$domaine),
        code = x$code,
        phase = as.integer(x$phase),
        prerequis = ids_num(x$prerequis),
        ouvre_vers = ids_num(x$dependants),
        termes_en = I(x$termes_en),
        fiche = i %in% avec_fiche
      )
    })
  )
}

exporter_mapping <- function(ref, fiches, sortie, racine = ".") {
  json <- jsonlite::toJSON(mapping_notions(ref, fiches, racine), auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null")
  con <- file(file.path(sortie, "boussole_lca_notions.json"), open = "wb")
  on.exit(close(con))
  writeBin(charToRaw(enc2utf8(paste0(json, "\n"))), con)
}
