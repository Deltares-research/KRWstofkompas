testthat::test_that("projectcriteria behouden onbekende wegingen zonder verzonnen score", {
  kader <- project_prioriteringskader()
  testthat::expect_equal(nrow(kader), 6L)
  testthat::expect_identical(kader$criterium, c(
    "normoverschrijding", "trend_niet_afnemend", "ruimtelijke_impact",
    "onzekerheid_kennisleemte", "beleidsurgentie", "handelingsperspectief"
  ))
  testthat::expect_true(all(is.na(kader$gewicht)))
  s <- tibble::tibble(stof = c("As", "PFOS"), heeft_toestand = c(TRUE, FALSE),
                      heeft_trend = c(TRUE, FALSE), heeft_emissie = c(TRUE, FALSE),
                      trend_landelijk = c("Geen significante trend", NA_character_))
  uit <- maak_projectprioritering(s)
  testthat::expect_equal(nrow(uit), 12L)
  testthat::expect_equal(anyDuplicated(uit[c("stof", "criterium")]), 0L)
  testthat::expect_true(all(is.na(uit$gewicht)))
  testthat::expect_true(all(uit$status[uit$criterium == "normoverschrijding"] == "Ontbreekt"))
  testthat::expect_match(uit$onderbouwing[uit$stof == "As" & uit$criterium == "trend_niet_afnemend"],
                         "geen bewijs voor een stabiele", ignore.case = TRUE)
  testthat::expect_equal(uit$status[uit$stof == "PFOS" & uit$criterium == "trend_niet_afnemend"], "Ontbreekt")
  testthat::expect_false(any(c("score", "rang", "totaalscore") %in% names(uit)))
})