# Réseau de dépendances -------------------------------------------------------------------------------
#
# Le DOT est identique à celui de build_lca.py. Le rendu SVG passe par DiagrammeRsvg (viz.js via V8),
# ce qui évite d'installer Graphviz ; le PDF est produit à partir du SVG par rsvg.

# strwrap() produit des lignes strictement plus courtes que `width` : 31 équivaut à textwrap.wrap(30).
envelopper <- function(txt, largeur = 30) paste(strwrap(txt, width = largeur + 1), collapse = "\\n")

dot_reseau <- function(ref) {
  info <- ref$info
  ordre <- ref$ordre
  g <- c("digraph G {",
         'rankdir=LR; splines=true; nodesep=0.12; ranksep=0.9; bgcolor="transparent";',
         'node [shape=box style="rounded,filled" fontname="Helvetica" fontsize=10 margin="0.08,0.04" width=2.1];',
         "edge [arrowsize=0.5 penwidth=0.8];")
  for (i in ordre) {
    x <- info[[i]]
    c <- x$cat
    lab <- paste0(envelopper(paste0(n3(info, i), ". ", x$libelle)), sprintf("\\nPhase %s - [%s]", x$phase, x$code))
    sty <- if (x$annee == 2) '"rounded,filled,dashed"' else '"rounded,filled"'
    g <- c(g, sprintf('n%s [label="%s" fillcolor="%s" color="%s" fontcolor="%s" style=%s penwidth=%s tooltip="%s"];',
                      n3(info, i), lab, FOND[[c]], COUL[[c]], TEXTE[[c]], sty,
                      if (x$annee == 2) "1.6" else "0.8", x$libelle))
  }
  for (i in ordre) {
    for (p in info[[i]]$prerequis) {
      g <- c(g, sprintf('n%s -> n%s [tailport=e headport=w color="%s70"];', n3(info, p), n3(info, i), COUL[[info[[p]]$cat]]))
    }
  }
  # notion isolée (ni prérequis ni dépendant) : alignée sur la notion précédente du parcours
  for (k in seq_along(ordre)[-1]) {
    i <- ordre[k]
    if (!length(info[[i]]$prerequis) && !length(info[[i]]$dependants)) {
      g <- c(g, sprintf("{rank=same; n%s; n%s;}", n3(info, i), n3(info, ordre[k - 1])))
    }
  }
  paste(c(g, "}"), collapse = "\n")
}

# grViz() échappe les apostrophes (d'évaluation -> d\'évaluation), ce que viz.js refuse :
# on transmet le DOT brut à export_svg() sous la forme du widget qu'elle attend.
# export_svg() lit viz.js dans le paquet DiagrammeR : dépendance déclarée explicitement pour renv.
svg_reseau <- function(dot) {
  stopifnot(requireNamespace("DiagrammeR", quietly = TRUE))
  DiagrammeRsvg::export_svg(list(x = list(diagram = dot, config = list(engine = "dot", options = NULL))))
}

# Écrit .dot, .svg, .pdf et renvoie le SVG prêt à intégrer dans la page (id="net", sans dimensions fixes).
exporter_reseau <- function(ref, sortie) {
  dot <- dot_reseau(ref)
  ecrire_utf8(dot, file.path(sortie, "reseau_lca.dot"))
  svg <- svg_reseau(dot)
  ecrire_utf8(svg, file.path(sortie, "reseau_lca.svg"))
  rsvg::rsvg_pdf(charToRaw(enc2utf8(svg)), file.path(sortie, "reseau_lca.pdf"))
  integrer_svg(svg)
}

integrer_svg <- function(svg) {
  svg <- substring(svg, regexpr("<svg", svg, fixed = TRUE))
  svg <- sub('<svg width="[^"]*" height="[^"]*"', '<svg id="net"', svg)
  sub('<polygon fill="white" stroke="(transparent|none)"[^>]*/>', "", svg)
}
