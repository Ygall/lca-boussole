test_that("les fiches réelles sont valides et triées", {
  ref <- charger(RACINE)
  fiches <- construire_fiches(ref, RACINE)
  expect_equal(vapply(fiches, `[[`, character(1), "titre")[1:2], c("025. Moyenne et écart-type", "036. Rapport de cotes"))
  oddsratio <- fiches[[2]]$html
  expect_match(oddsratio, "<table>", fixed = TRUE)
  expect_match(oddsratio, "071. Rapport de cotes, seule mesure estimable", fixed = TRUE)
  expect_match(oddsratio, '<a target="_blank" rel="noopener" href=', fixed = TRUE)
  expect_false(grepl("[[", oddsratio, fixed = TRUE))
})

test_that("un renvoi ou une fiche inconnus arrêtent la génération", {
  dir <- racine_temporaire()
  ref <- charger(dir)
  writeLines("Voir [[notion-inexistante]].", file.path(dir, "fiches", "rapport-de-cotes.md"))
  writeLines("Corps.", file.path(dir, "fiches", "fiche-sans-notion.md"))
  err <- analyser_fiches(ref, dir)$erreurs
  expect_match(err, "renvoi \\[\\[notion-inexistante\\]\\] inconnu", all = FALSE)
  expect_match(err, "fiche-sans-notion.md : identifiant inconnu", all = FALSE)
  expect_error(construire_fiches(ref, dir), "Fiches invalides")
})

test_that("le DOT contient toutes les notions et dépendances", {
  dot <- dot_reseau(charger(RACINE))
  expect_equal(length(gregexpr("\nn\\d{3} \\[label=", dot)[[1]]), 143)
  expect_equal(length(gregexpr("\nn\\d{3} -> n\\d{3} ", dot)[[1]]), 202)
  expect_match(dot, 'n036 [label="036. Rapport de cotes\\nPhase 5 - [B7]"', fixed = TRUE)
})

test_that("le gabarit est entièrement rempli", {
  expect_equal(remplir("a {{X}} b {{Y}}", list(X = "1$\\2", Y = 3)), "a 1$\\2 b 3")
  expect_error(remplir("{{X}} {{Z}}", list(X = "1")), "champs non remplis")
})

test_that("les données injectées ne ferment pas la balise script", {
  ref <- charger(RACINE)
  js <- donnees_js(ref, construire_fiches(ref, RACINE))
  expect_false(grepl("</script", js, fixed = TRUE))
  expect_match(js, '"n036":{"num":"036","t":"Rapport de cotes","c":"B7","p":5,"lvl":"base"}', fixed = TRUE)
})
