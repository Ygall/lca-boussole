# Cartes mentales : exports Markdown / Freeplane et arbres Markmap ----------------------------------

esc_xml <- function(s) {
  s <- gsub("&", "&amp;", s, fixed = TRUE)
  s <- gsub("<", "&lt;", s, fixed = TRUE)
  s <- gsub(">", "&gt;", s, fixed = TRUE)
  gsub('"', "&quot;", s, fixed = TRUE)
}

esc_html <- function(s) {
  s <- esc_xml(s)
  gsub("'", "&#x27;", s, fixed = TRUE)
}

domaine <- function(ref, d) ref$doms[[which(vapply(ref$doms, function(x) x$numero == d, logical(1)))]]

ecrire_utf8 <- function(lignes, chemin) {
  con <- file(chemin, open = "wb")
  on.exit(close(con))
  writeBin(charToRaw(enc2utf8(paste(lignes, collapse = "\n"))), con)
}

exporter_cartes <- function(ref, sortie) {
  info <- ref$info
  libs <- function(ids) vapply(as.character(unlist(ids)), function(i) info[[i]]$libelle, character(1))

  # carte des notions
  md <- c("# Carte mentale des notions de lecture critique d'article (EDN)", "")
  mm <- c('<map version="freeplane 1.9.13">',
          '<node TEXT="Lecture critique d\'article - EDN" FOLDED="false" BACKGROUND_COLOR="#F1EFE8"><font SIZE="18" BOLD="true"/>',
          '<node TEXT="Légende : fond bleu = base (année 1), italique gris = avancé (année 2)" POSITION="left" COLOR="#5F5E5A"><font SIZE="10"/></node>')
  for (k in seq_along(ref$cats)) {
    c <- ref$cats[[k]]
    col <- COUL[[c$code]]
    md <- c(md, paste0("## ", c$code, ". ", c$libelle), "")
    mm <- c(mm, sprintf('<node TEXT="%s" POSITION="%s" FOLDED="false" COLOR="%s"><edge COLOR="%s" WIDTH="3"/><font SIZE="15" BOLD="true"/>',
                        esc_xml(paste0(c$code, ". ", c$libelle)), if (k %% 2 == 1) "right" else "left", col, col))
    for (d in c$domaines) {
      dd <- domaine(ref, d)
      md <- c(md, sprintf("### Domaine %s. %s", d, dd$libelle), "", "- Base (année 1)",
              paste0("  - ", libs(dd$base)),
              "- Avancé (année 2)", paste0("  - ", libs(dd$avance)), "")
      mm <- c(mm, sprintf('<node TEXT="%s" FOLDED="false" COLOR="%s"><edge COLOR="%s" WIDTH="2"/><font SIZE="13" BOLD="true"/>',
                          esc_xml(sprintf("Domaine %s. %s", d, dd$libelle)), col, col))
      for (l in libs(dd$base)) {
        mm <- c(mm, sprintf('<node TEXT="%s" COLOR="#0C447C" BACKGROUND_COLOR="#E6F1FB"><edge COLOR="%s" WIDTH="1"/><font SIZE="11"/></node>', esc_xml(l), col))
      }
      for (l in libs(dd$avance)) {
        mm <- c(mm, sprintf('<node TEXT="%s" COLOR="#5F5E5A"><edge COLOR="%s" WIDTH="1"/><font SIZE="11" ITALIC="true"/></node>', esc_xml(l), col))
      }
      mm <- c(mm, "</node>")
    }
    mm <- c(mm, "</node>")
  }
  mm <- c(mm, "</node>", "</map>")
  ecrire_utf8(md, file.path(sortie, "carte_mentale_lca.md"))
  xml2::read_xml(paste(mm, collapse = "\n"))
  ecrire_utf8(mm, file.path(sortie, "carte_mentale_lca.mm"))

  # parcours (phases chaînées en escalier)
  N <- length(info)
  md <- c(sprintf("# Parcours d'apprentissage LCA (%d notions)", N), "",
          "Le code entre crochets indique catégorie et domaine ; les numéros après la flèche sont les prérequis directs.", "")
  mm <- c('<map version="freeplane 1.9.13">',
          sprintf('<node TEXT="Parcours LCA - %d notions" FOLDED="false" BACKGROUND_COLOR="#F1EFE8" STYLE="bubble"><font SIZE="18" BOLD="true"/>', N),
          '<node TEXT="Légende : [A1] = catégorie A, domaine 1 ; ← = notions prérequises ; couleur = catégorie" POSITION="left" COLOR="#5F5E5A"><font SIZE="10"/></node>')
  annee <- NULL
  for (k in seq_along(ref$parc)) {
    ph <- ref$parc[[k]]
    ids <- vapply(ph$notions, function(n) n$id, character(1))
    if (!identical(ph$annee, annee)) {
      annee <- ph$annee
      md <- c(md, sprintf("## Année %s (%s)", annee, if (annee == 1) "notions de base" else "notions avancées"), "")
    }
    md <- c(md, sprintf("### Phase %s. %s", ph$numero, ph$titre), "",
            paste0("- ", vapply(ids, function(i) ligne_parcours(info, i), character(1))), "")
    mm <- c(mm, sprintf('<node TEXT="%s"%s FOLDED="false" BACKGROUND_COLOR="#F1EFE8" STYLE="bubble"><font SIZE="13" BOLD="true"/><edge STYLE="horizontal" COLOR="#888780" WIDTH="3"/>',
                        esc_xml(sprintf("Année %s - Phase %s. %s", annee, ph$numero, ph$titre)),
                        if (k == 1) ' POSITION="right"' else ""))
    for (i in ids) {
      col <- COUL[[info[[i]]$cat]]
      mm <- c(mm, sprintf('<node TEXT="%s" COLOR="%s" STYLE="fork"><font SIZE="11"/><edge STYLE="bezier" COLOR="%s" WIDTH="1"/></node>',
                          esc_xml(ligne_parcours(info, i)), col, col))
    }
  }
  mm <- c(mm, rep("</node>", length(ref$parc)), "</node>", "</map>")
  ecrire_utf8(md, file.path(sortie, "parcours_lca.md"))
  xml2::read_xml(paste(mm, collapse = "\n"))
  ecrire_utf8(mm, file.path(sortie, "parcours_lca.mm"))
  invisible(NULL)
}

# Arbres Markmap --------------------------------------------------------------------------------------

STYLES_NOEUD <- c(
  cat = "font-weight:700;font-size:16px",
  dom = "font-weight:600",
  lv  = "font-style:italic;color:var(--muted)",
  b   = "padding:1px 6px;border-radius:4px;background:rgba(55,138,221,.16)",
  a   = "padding:1px 6px;border-radius:4px;border:1px dashed var(--muted)"
)

noeud <- function(txt, cat, enfants = NULL, fold = 0L, cls = "") {
  n <- list(
    content = if (nzchar(cls)) sprintf('<span style="%s">%s</span>', STYLES_NOEUD[[cls]], esc_html(txt)) else esc_html(txt),
    payload = list(cat = cat, fold = fold)
  )
  if (length(enfants)) n$children <- enfants
  n
}

arbre_notions <- function(ref) {
  info <- ref$info
  feuilles <- function(ids, cat, cls) lapply(as.character(unlist(ids)), function(i) noeud(info[[i]]$libelle, cat, cls = cls))
  noeud("Lecture critique d'article - EDN", "R", lapply(ref$cats, function(c) {
    noeud(paste0(c$code, ". ", c$libelle), c$code, lapply(c$domaines, function(d) {
      dd <- domaine(ref, d)
      noeud(sprintf("Domaine %s. %s", d, dd$libelle), c$code, list(
        noeud("Base (année 1)", c$code, feuilles(dd$base, c$code, "b"), cls = "lv"),
        noeud("Avancé (année 2)", c$code, feuilles(dd$avance, c$code, "a"), cls = "lv")
      ), fold = 1L, cls = "dom")
    }), cls = "cat")
  }))
}

arbre_parcours <- function(ref) {
  info <- ref$info
  noeud(sprintf("Parcours LCA - %d notions", length(info)), "R", lapply(1:2, function(a) {
    phs <- Filter(function(ph) ph$annee == a, ref$parc)
    noeud(sprintf("Année %d - %s", a, if (a == 1) "notions de base" else "notions avancées"), "R", lapply(phs, function(ph) {
      noeud(sprintf("Phase %s. %s", ph$numero, ph$titre), "R", lapply(ph$notions, function(n) {
        noeud(ligne_parcours(info, n$id), info[[n$id]]$cat, cls = if (a == 1) "b" else "a")
      }), cls = "dom")
    }), cls = "cat")
  }))
}
