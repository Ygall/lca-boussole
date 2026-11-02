# Cartes mentales : arbres Markmap de la page ------------------------------------------------------

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
        noeud("Base", c$code, feuilles(dd$base, c$code, "b"), cls = "lv"),
        noeud("Avancé", c$code, feuilles(dd$avance, c$code, "a"), cls = "lv")
      ), fold = 1L, cls = "dom")
    }), cls = "cat")
  }))
}

arbre_parcours <- function(ref) {
  info <- ref$info
  noeud(sprintf("Parcours LCA - %d notions", length(info)), "R", lapply(c("base", "avance"), function(niv) {
    phs <- Filter(function(ph) ph$niveau == niv, ref$parc)
    noeud(LIBELLE_NIVEAU[[niv]], "R", lapply(phs, function(ph) {
      noeud(sprintf("Phase %s. %s", ph$numero, ph$titre), "R", lapply(ph$notions, function(n) {
        noeud(ligne_parcours(info, n$id), info[[n$id]]$cat, cls = if (niv == "base") "b" else "a")
      }), cls = "dom")
    }), cls = "cat")
  }))
}
