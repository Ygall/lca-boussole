test_that("le référentiel réel est cohérent", {
  ref <- charger(RACINE)
  expect_length(ref$ordre, 143)
  expect_equal(sum(vapply(ref$info, function(x) x$niveau == "base", logical(1))), 81)
  expect_true(all(nzchar(vapply(ref$info, `[[`, character(1), "description"))))
  expect_true(all(lengths(lapply(ref$info, `[[`, "termes_en")) > 0))
  expect_equal(sum(lengths(lapply(ref$info, `[[`, "prerequis"))), 202)
  expect_equal(n3(ref$info, c("structure-imrad", "rapport-de-cotes")), c("001", "036"))
  expect_equal(ligne_parcours(ref$info, "rapport-de-cotes"), "036. Rapport de cotes [B7] ← 032")
})

test_that("un prérequis inconnu est signalé", {
  err <- erreurs_apres(function(ref) {
    p <- position(ref, "rapport-de-cotes")
    ref$parc[[p[1]]]$notions[[p[2]]]$prerequis <- list("notion-inexistante")
    ref
  })
  expect_match(err, "rapport-de-cotes : prérequis notion-inexistante inconnu", all = FALSE)
})

test_that("un cycle de dépendances est signalé (prérequis placé après la notion)", {
  err <- erreurs_apres(function(ref) {
    p <- position(ref, "structure-imrad")
    ref$parc[[p[1]]]$notions[[p[2]]]$prerequis <- list("vocabulaire-methodologique-anglais")
    ref
  })
  expect_match(err, "structure-imrad : prérequis vocabulaire-methodologique-anglais inconnu ou placé après", all = FALSE)
})

test_that("une notion avancée placée dans une phase de base est signalée", {
  err <- erreurs_apres(function(ref) {
    ref$doms[[1]]$base <- setdiff(unlist(ref$doms[[1]]$base), "structure-imrad")
    ref$doms[[1]]$avance <- c(unlist(ref$doms[[1]]$avance), "structure-imrad")
    ref
  })
  expect_equal(err, "structure-imrad : niveau avance incohérent avec la phase 1 (base)")
})

test_that("niveau de phase invalide ou phase de base après une phase avancée sont signalés", {
  err <- erreurs_apres(function(ref) {
    ref$parc[[1]]$niveau <- "annee1"
    ref$parc <- c(ref$parc[-2], ref$parc[2])
    ref
  })
  expect_match(err, "phase 1 : niveau annee1 invalide", all = FALSE)
  expect_match(err, "phase 2 : phase de base placée après une phase avancée", all = FALSE)
})

test_that("une description manquante est signalée", {
  err <- erreurs_apres(function(ref) {
    ref$lib[["rapport-de-cotes"]]$description <- ""
    ref
  })
  expect_equal(err, "notion rapport-de-cotes : description manquant dans notions.yml")
})

test_that("identifiants dupliqués, absents ou orphelins sont signalés", {
  err <- erreurs_apres(function(ref) {
    ref$doms[[1]]$base <- c(ref$doms[[1]]$base, "structure-imrad")
    ref$lib[["notion-orpheline"]] <- list(libelle = "Notion orpheline", description = "Test.")
    ref
  })
  expect_match(err, "notion structure-imrad présente dans plusieurs domaines", all = FALSE)
  expect_match(err, "notions orphelines dans notions.yml : notion-orpheline", all = FALSE)
})

test_that("charger() s'arrête avec un message explicite", {
  dir <- racine_temporaire()
  parc <- file.path(dir, "data", "parcours.yml")
  txt <- readLines(parc, encoding = "UTF-8")
  txt <- sub("prerequis: [structure-imrad]", "prerequis: [inconnue]", txt, fixed = TRUE)
  writeLines(enc2utf8(txt), parc, useBytes = TRUE)
  expect_error(charger(dir), "Référentiels invalides")
})
