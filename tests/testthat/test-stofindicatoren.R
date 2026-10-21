# Kleine bronfixtures met alle kolommen die de gedeelde helpers gebruiken.
fixture_toestand <- function() {
  tibble::tibble(
    KRWkwaliteitselementCode = rep("A", 9),
    Rapportagejaar = c("2023", rep("2024", 6), NA_character_, "onbekend"),
    WaterlichaamCode = c("oud", "WL1", "WL1", "WL2", "", NA, "WL3", "WL4", "WL5"),
    Beheerdersoordeel = c("Nee", "Ja", "Nee", "Ja", "Nee", NA, "Nee", "Ja", "Nee"),
    Classificatie = c("Voldoet niet", "Voldoet niet", "Voldoet", "Niet toetsbaar",
                     "Niet van toepassing", "Onbekende klasse", NA, "Voldoet", "Voldoet")
  )
}

fixture_trends <- function() {
  tibble::tibble(
    parameter_code = rep("A", 9),
    aggregatieniveau = c("Landelijk", "Stroomgebied", "Waterlichaam", rep("Meetpunt", 6)),
    regio_omschrijving = c("Nederland", "Rijn", "WL1", "M1", "M2", "M3", "M4", "M5", "M6"),
    trend_conclusie = c("Geen trend", "Dalende trend", "Stijgende trend",
                       "Stijgende trend", "Dalende trend", "Geen trend",
                       "Geen significante trend", "Te weinig metingen voor een trend", NA)
  )
}

fixture_emissies <- function() {
  tibble::tibble(
    compartiment = c("riool", "riool", "water", "water", "water", "riool"),
    Stofcode = rep("ER1", 6), Stof = rep("Voorbeeldstof", 6),
    Jaar = c(2023L, 2024L, 2024L, 2024L, 2024L, NA_integer_),
    Sector = c("Oud", "Rioolsector", "Zulu", "Alpha", "Klein", "Zonder jaar"),
    Subsector = rep("Subsector", 6), Emissieoorzaak = rep("Oorzaak", 6),
    Emissie = c(999, 8, 5, 5, 0, 1000), Eenheid = rep("kg", 6)
  )
}

fixture_bronnen <- function() {
  emissies <- fixture_emissies()
  list(
    normen_rivm = tibble::tibble(
      aquo_code = c("A", "A", "NORM_ALLEEN"),
      stofnaam = c("Voorbeeldstof", "Voorbeeldstof", "Alleen norm"),
      cas_nummer = c("123-45-6", "123-45-6", "999-99-9"),
      compartiment = c("water", "sediment", "water"),
      norm = c("JG-MKN", "MTR", "JG-MKN"), waarde = c(1, 2, 3),
      eenheid = c("ug/l", "mg/kg", "ug/l")
    ),
    toestand_wkp = fixture_toestand(),
    chemtrend_trend_samenvatting_info_data = fixture_trends(),
    rekenfactoren_er_cleaned = tibble::tibble(
      aquo_code = c("A", "A", "A", "EMISSIE_ALLEEN"),
      gepresenteerde_stof_code = c("ER1", "ER1", "ER2", "ER3")
    ),
    emissies_op_riool = emissies[emissies$compartiment == "riool", setdiff(names(emissies), "compartiment")],
    emissies_op_water = emissies[emissies$compartiment == "water", setdiff(names(emissies), "compartiment")]
  )
}

testthat::test_that("toestand gebruikt recente oordelen, niet het aantal waterlichamen", {
  uit <- vat_toestand_samen(fixture_toestand())
  testthat::expect_equal(nrow(uit), 1L)
  testthat::expect_equal(uit$toestand_jaar, 2024L)
  testthat::expect_equal(uit$toestand_n_oordelen, 6L)
  testthat::expect_equal(uit$toestand_n_waterlichamen, 3L)
  testthat::expect_equal(uit$toestand_n_beheerdersoordeel, 2L)
  testthat::expect_equal(uit$toestand_n_zonder_jaar, 2L)
  testthat::expect_equal(uit$toestand_n_onbekend, 2L)
  for (naam in c("voldoet_niet", "voldoet", "niet_toetsbaar", "niet_van_toepassing")) {
    testthat::expect_equal(uit[[paste0("toestand_n_", naam)]], 1L)
    testthat::expect_equal(uit[[paste0("toestand_pct_", naam)]], 100 / 6)
  }
})

testthat::test_that("lege toestand en ongeldige jaren leveren NA in plaats van nul", {
  d <- fixture_toestand()
  d$Rapportagejaar <- rep(NA_character_, nrow(d))
  for (data in list(d, d[0, ])) {
    uit <- vat_toestand_samen(data)
    testthat::expect_true(is.na(uit$toestand_jaar))
    testthat::expect_equal(uit$toestand_n_zonder_jaar, nrow(data))
    overige <- uit[setdiff(names(uit), "toestand_n_zonder_jaar")]
    testthat::expect_true(all(is.na(unlist(overige))))
  }
  d <- fixture_toestand()[2, ]
  d$Rapportagejaar <- factor("2025")
  uit <- vat_toestand_samen(d)
  testthat::expect_equal(uit$toestand_jaar, 2025L)
  testthat::expect_equal(uit$toestand_n_voldoet, 0L)
  testthat::expect_equal(uit$toestand_pct_voldoet, 0)
})

testthat::test_that("trends standaardiseren geen trend en gebruiken geldige brontrends", {
  uit <- vat_trends_samen(fixture_trends())
  testthat::expect_identical(uit$aggregatieniveau,
                           c("Landelijk", "Stroomgebied", "Waterlichaam", "Meetpunt"))
  testthat::expect_equal(uit$conclusie[1], "Geen significante trend")
  meetpunt <- uit[uit$aggregatieniveau == "Meetpunt", ]
  testthat::expect_equal(meetpunt$aantal_totaal, 6L)
  testthat::expect_equal(meetpunt$aantal_trend, 4L)
  testthat::expect_equal(meetpunt$aantal_onvoldoende, 2L)
  testthat::expect_equal(meetpunt$aantal_geen, 2L)
  testthat::expect_equal(meetpunt$percentage_stijgend, 25)
  testthat::expect_equal(meetpunt$percentage_dalend, 25)
  testthat::expect_equal(meetpunt$percentage_geen, 50)
})

testthat::test_that("lege of ongeldige trends hebben geen berekenbare percentages", {
  d <- fixture_trends()[0, ]
  uit <- vat_trends_samen(d)
  testthat::expect_equal(nrow(uit), 4L)
  testthat::expect_true(all(uit$aantal_totaal == 0))
  testthat::expect_true(all(is.na(uit$conclusie)))
  testthat::expect_true(all(is.na(uit$percentage_stijgend)))
  d <- fixture_trends()[4:5, ]
  d$trend_conclusie <- c("Te weinig metingen voor een trend", "Onbekend")
  uit <- vat_trends_samen(d)
  meetpunt <- uit[uit$aggregatieniveau == "Meetpunt", ]
  testthat::expect_equal(meetpunt$aantal_trend, 0L)
  testthat::expect_equal(meetpunt$aantal_onvoldoende, 2L)
  testthat::expect_true(all(is.na(meetpunt[c("percentage_stijgend", "percentage_dalend", "percentage_geen")])))
})

testthat::test_that("dubbele regios worden gesignaleerd maar niet stil gededupliceerd", {
  d <- fixture_trends()
  d <- dplyr::bind_rows(d, d[4, ])
  uit <- vat_trends_samen(d)
  meetpunt <- uit[uit$aggregatieniveau == "Meetpunt", ]
  testthat::expect_equal(meetpunt$n_dubbele_regios, 1L)
  testthat::expect_equal(meetpunt$aantal_totaal, 7L)
  testthat::expect_equal(meetpunt$aantal_trend, 5L)
  testthat::expect_equal(meetpunt$percentage_stijgend, 40)
})

testthat::test_that("emissies gebruiken een gedeeld laatste jaar en behouden sector-ties", {
  uit <- vat_emissies_samen(fixture_emissies())
  testthat::expect_equal(uit$emissie_jaar, 2024L)
  testthat::expect_true(uit$emissie_riool_geldig)
  testthat::expect_equal(uit$emissie_riool_totaal, 8)
  testthat::expect_equal(uit$emissie_riool_n_regels, 1L)
  testthat::expect_equal(uit$emissie_water_totaal, 10)
  testthat::expect_equal(uit$emissie_water_eenheid, "kg")
  testthat::expect_equal(uit$emissie_water_top_sector, "Alpha; Zulu")
  testthat::expect_equal(uit$emissie_water_top_sector_pct, 50)
  d <- fixture_emissies()
  testthat::expect_equal(vat_emissies_samen(d[nrow(d):1, ]), uit)
  d$Jaar[d$compartiment == "riool"] <- 2023L
  uit <- vat_emissies_samen(d)
  testthat::expect_equal(uit$emissie_jaar, 2024L)
  testthat::expect_equal(uit$emissie_riool_laatst_beschikbaar_jaar, 2023L)
  testthat::expect_equal(uit$emissie_riool_n_regels, 0L)
  testthat::expect_false(uit$emissie_riool_geldig)
  testthat::expect_true(is.na(uit$emissie_riool_totaal))
  testthat::expect_equal(uit$emissie_water_totaal, 10)
})

testthat::test_that("sectorbijdragen worden eerst per sector opgeteld", {
  d <- fixture_emissies()[3:5, ]
  d$Sector <- c("Groot", "Klein", "Groot")
  d$Emissie <- c(3, 4, 3)
  uit <- vat_emissies_samen(d)
  testthat::expect_equal(uit$emissie_water_top_sector, "Groot")
  testthat::expect_equal(uit$emissie_water_top_sector_pct, 60)
})

testthat::test_that("gemengde of ontbrekende eenheden maken geen optelbaar totaal", {
  for (eenheden in list(c("kg", "g", "kg"), c(NA, NA, NA),
                       c("", "", ""), c("kg", NA, "kg"))) {
    d <- fixture_emissies()[3:5, ]
    d$Eenheid <- eenheden
    uit <- vat_emissies_samen(d)
    testthat::expect_false(uit$emissie_water_geldig)
    testthat::expect_true(is.na(uit$emissie_water_totaal))
    testthat::expect_true(is.na(uit$emissie_water_top_sector_pct))
    testthat::expect_true(is.na(uit$emissie_water_top_sector))
  }
  d <- fixture_emissies()
  d$Eenheid[d$compartiment == "water"] <- "g"
  uit <- vat_emissies_samen(d)
  testthat::expect_true(uit$emissie_riool_geldig && uit$emissie_water_geldig)
  testthat::expect_equal(uit$emissie_riool_eenheid, "kg")
  testthat::expect_equal(uit$emissie_water_eenheid, "g")
})

testthat::test_that("NA, niet-eindige en negatieve emissies zijn geen waargenomen nul", {
  for (waarden in list(c(NA_real_, NA, NA), c(1, NA, 2), c(1, Inf, 2), c(1, -1, 2))) {
    d <- fixture_emissies()[3:5, ]
    d$Emissie <- waarden
    uit <- vat_emissies_samen(d)
    testthat::expect_false(uit$emissie_water_geldig)
    testthat::expect_true(is.na(uit$emissie_water_totaal))
  }
  d <- fixture_emissies()[3:5, ]
  d$Emissie <- 0
  uit <- vat_emissies_samen(d)
  testthat::expect_true(uit$emissie_water_geldig)
  testthat::expect_equal(uit$emissie_water_totaal, 0)
  testthat::expect_true(is.na(uit$emissie_water_top_sector_pct))
  testthat::expect_equal(uit$emissie_water_top_sector, "Alpha; Klein; Zulu")
  for (data in list(d[0, ], dplyr::mutate(d, Jaar = NA_integer_))) {
    uit <- vat_emissies_samen(data)
    testthat::expect_true(is.na(uit$emissie_jaar))
    testthat::expect_false(uit$emissie_water_geldig)
    testthat::expect_true(is.na(uit$emissie_water_totaal))
  }
})

testthat::test_that("stofselectie is toestand-union-trend, niet emissies of normen", {
  bronnen <- fixture_bronnen()
  bronnen$toestand_wkp$KRWkwaliteitselementCode <- c("B", "A", "", NA, rep("A", 5))
  bronnen$chemtrend_trend_samenvatting_info_data$parameter_code <- c("C", rep("A", 8))
  extra <- bronnen$emissies_op_water[1, ]
  extra$Stofcode <- "ER3"
  bronnen$emissies_op_water <- dplyr::bind_rows(bronnen$emissies_op_water, extra)
  uit <- bepaal_stoffen(bronnen)
  testthat::expect_identical(uit$stof, c("A", "B", "C"))
  testthat::expect_identical(uit$heeft_toestand, c(TRUE, TRUE, FALSE))
  testthat::expect_identical(uit$heeft_trend, c(TRUE, FALSE, TRUE))
  testthat::expect_identical(uit$heeft_emissie, c(TRUE, FALSE, FALSE))
  testthat::expect_false(any(c("EMISSIE_ALLEEN", "NORM_ALLEEN") %in% uit$stof))
})

testthat::test_that("meerdere ER-codes en dubbele koppelingen vermenigvuldigen geen bronregels", {
  bronnen <- fixture_bronnen()
  extra <- bronnen$emissies_op_water[1, ]
  extra$Stofcode <- "ER2"
  extra$Emissie <- 7
  bronnen$emissies_op_water <- dplyr::bind_rows(bronnen$emissies_op_water, extra)
  data <- selecteer_stofbronnen("A", bronnen)
  testthat::expect_equal(nrow(data$normen), 2L)
  testthat::expect_equal(nrow(data$emissies), 7L)
  testthat::expect_setequal(data$emissies$Stofcode, c("ER1", "ER2"))
  uit <- bereken_stofindicatoren("A", data)
  testthat::expect_equal(uit$emissie_water_totaal, 17)
  testthat::expect_equal(nrow(uit), 1L)
})

testthat::test_that("gedeelde eenrijige indicatoren komen overeen met alle deelsamenvattingen", {
  data <- selecteer_stofbronnen("A", fixture_bronnen())
  uit <- bereken_stofindicatoren("A", data)
  testthat::expect_s3_class(uit, "tbl_df")
  testthat::expect_equal(nrow(uit), 1L)
  testthat::expect_identical(uit$stof, "A")
  testthat::expect_equal(uit$normen_n, 2L)
  testthat::expect_equal(uit$stofnaam, "Voorbeeldstof")
  testthat::expect_equal(uit$cas_nummer, "123-45-6")
  testthat::expect_true(uit$heeft_toestand && uit$heeft_trend && uit$heeft_emissie)
  for (deel in list(vat_toestand_samen(data$toestand), vat_emissies_samen(data$emissies))) {
    testthat::expect_equal(uit[names(deel)], deel)
  }
  testthat::expect_equal(uit$trend_landelijk, "Geen significante trend")
  testthat::expect_equal(uit$trend_meetpunt_n_trend, 4L)
  testthat::expect_equal(uit$trend_meetpunt_percentage_stijgend, 25)
  leeg <- bereken_stofindicatoren("AFWEZIG", selecteer_stofbronnen("AFWEZIG", fixture_bronnen()))
  testthat::expect_equal(nrow(leeg), 1L)
  testthat::expect_false(leeg$heeft_toestand || leeg$heeft_trend || leeg$heeft_emissie)
  testthat::expect_equal(leeg$normen_n, 0L)
  testthat::expect_true(is.na(leeg$trend_meetpunt_n_trend))
  testthat::expect_true(is.na(leeg$toestand_n_oordelen))
  testthat::expect_true(is.na(leeg$emissie_water_totaal))
  testthat::expect_false(any(grepl("prioriteit|score", names(uit))))
})

testthat::test_that("voorbereide indicatoren zijn rechtstreeks leesbaar en vereisen een unieke stof", {
  uit <- bereken_stofindicatoren("A", selecteer_stofbronnen("A", fixture_bronnen()))
  bestand <- tempfile(fileext = ".rds")
  saveRDS(uit, bestand)
  testthat::expect_equal(lees_stofindicatoren("A", bestand = bestand), uit)
  csv <- tempfile(fileext = ".csv")
  readr::write_csv(uit, csv, na = "")
  terug <- readr::read_csv(csv, show_col_types = FALSE)
  testthat::expect_equal(terug$stof, uit$stof)
  for (naam in names(uit)[vapply(uit, is.numeric, logical(1))]) {
    # Een volledig ontbrekende CSV-kolom kan als logical worden ingelezen.
    testthat::expect_equal(as.numeric(terug[[naam]]), as.numeric(uit[[naam]]))
  }
  testthat::expect_type(terug$toestand_pct_voldoet_niet, "double")
  testthat::expect_type(terug$emissie_water_totaal, "double")
  definities <- vapply(names(uit), indicator_definitie, character(1))
  testthat::expect_true(all(!is.na(definities) & nzchar(definities)))
  testthat::expect_error(lees_stofindicatoren("B", bestand = bestand), "Geen unieke indicatorenrij")
  saveRDS(dplyr::bind_rows(uit, uit), bestand)
  testthat::expect_error(lees_stofindicatoren("A", bestand = bestand), "Geen unieke indicatorenrij")
})

# Alleen projectgeneratie, geen Quarto/RIVM/GIS/Arrow of externe schijf.
fixture_boek <- function() {
  root <- tempfile(pattern = "stoffenboek-test-")
  templates <- file.path(root, "scripts", "2_rapport_templates")
  dir.create(templates, recursive = TRUE)
  writeLines(c(
    "---", "title: Fixture", "---", "```{r}", "#| label: setup",
    'source(here::here("scripts", "0_algemeen", "setup.R"))', "```",
    "{{< include 00_samenvatting.qmd >}}", "{{< include 01_stofinformatie.qmd >}}",
    '```{r}', '#| label: details',
    'knitr::knit_child(here::here("scripts", "2_rapport_templates", "02_toestandsoordelen.qmd"))',
    '```'
  ), file.path(templates, "stofrapport.qmd"))
  writeLines(c("# Samenvatting {#sec-overzicht}", "[Details](#sec-details)", "Zie @tbl-data."),
             file.path(templates, "00_samenvatting.qmd"))
  writeLines(c("# Stofinformatie", "```{r}", "#| label: tbl-data", "1", "```"),
             file.path(templates, "01_stofinformatie.qmd"))
  writeLines(c("# Toestand {#sec-details}", "```{r}", "#| label: fig-kaart", "1", "```"),
             file.path(templates, "02_toestandsoordelen.qmd"))
  writeLines("# Indicatoren", file.path(templates, "00_rangschikking.qmd"))
  writeLines("body {}", file.path(templates, "stofrapport.css"))
  export_dir <- file.path(root, "export")
  dir.create(export_dir)
  stoffen <- tibble::tibble(
    stof = c("A/B", "A B", "a-b", "!!!"),
    heeft_toestand = TRUE, heeft_trend = FALSE, heeft_emissie = FALSE
  )
  indicatoren <- tibble::tibble(stof = stoffen$stof)
  saveRDS(indicatoren, file.path(export_dir, "stofindicatoren.rds"))
  readr::write_csv(indicatoren, file.path(export_dir, "stofindicatoren.csv"))
  bron <- file.path(root, "bron.rds")
  saveRDS(list(fixture = TRUE), bron)
  list(
    root = root,
    paths = list(interim = file.path(root, "interim"), output = file.path(root, "output")),
    export = list(stoffen = stoffen, indicatoren = indicatoren,
                  bestanden = list(fixture = bron), export_dir = export_dir)
  )
}

testthat::test_that("boekgenerator voorkomt botsende bestandsnamen, labels en anchors zonder render", {
  fixture <- fixture_boek()
  manifest <- maak_stoffenboek(fixture$paths, root = fixture$root,
                             export = fixture$export, render = FALSE)
  testthat::expect_identical(manifest$status, "prepared")
  hoofdstukken <- manifest$hoofdstukken
  testthat::expect_equal(nrow(hoofdstukken), 4L)
  testthat::expect_equal(anyDuplicated(hoofdstukken$hoofdstuk), 0L)
  testthat::expect_equal(anyDuplicated(hoofdstukken$prefix), 0L)
  testthat::expect_true(all(grepl("^stof-[0-9]{4}-[a-z0-9-]+\\.qmd$", hoofdstukken$hoofdstuk)))
  testthat::expect_false(dir.exists(fixture$paths$output))
  alle_labels <- character()
  for (i in seq_len(nrow(hoofdstukken))) {
    prefix <- hoofdstukken$prefix[i]
    map <- file.path(manifest$project, "partials", prefix)
    master <- readLines(file.path(manifest$project, hoofdstukken$hoofdstuk[i]))
    samenvatting <- readLines(file.path(map, "00_samenvatting.qmd"))
    info <- readLines(file.path(map, "01_stofinformatie.qmd"))
    toestand <- readLines(file.path(map, "02_toestandsoordelen.qmd"))
    testthat::expect_true(any(grepl(paste0("{#sec-", prefix, "-overzicht}"), samenvatting, fixed = TRUE)))
    testthat::expect_true(any(grepl(paste0("](#sec-", prefix, "-details)"), samenvatting, fixed = TRUE)))
    testthat::expect_true(any(grepl(paste0("@tbl-", prefix, "-data"), samenvatting, fixed = TRUE)))
    testthat::expect_true(any(grepl(paste0("#| label: tbl-", prefix, "-data"), info, fixed = TRUE)))
    testthat::expect_true(any(grepl(paste0("```{r fig-", prefix, "-kaart}"), toestand, fixed = TRUE)))
    testthat::expect_true(any(grepl("^## Samenvatting", samenvatting)))
    labels <- grep("^#\\| label:", c(master, info), value = TRUE)
    alle_labels <- c(alle_labels, labels, grep("^```\\{r .+\\}", toestand, value = TRUE))
    params <- readRDS(file.path(map, "params.rds"))
    testthat::expect_identical(params$stof, hoofdstukken$stof[i])
    testthat::expect_equal(params$indicatoren_bestand,
                           file.path(manifest$project, "downloads", "stofindicatoren.rds"))
  }
  testthat::expect_equal(anyDuplicated(alle_labels), 0L)
  testthat::expect_equal(readRDS(file.path(manifest$project, "downloads", "stofindicatoren.rds")),
                         fixture$export$indicatoren)
  yaml <- readLines(file.path(manifest$project, "_quarto.yml"))
  testthat::expect_true(all(paste0("    - ", hoofdstukken$hoofdstuk) %in% yaml))
})

testthat::test_that("boekgenerator weigert dubbele stofcodes en botsende chunklabels", {
  fixture <- fixture_boek()
  fixture$export$stoffen$stof[2] <- fixture$export$stoffen$stof[1]
  testthat::expect_error(
    maak_stoffenboek(fixture$paths, root = fixture$root, export = fixture$export, render = FALSE),
    "unieke, niet-lege stofcodes"
  )
  testthat::expect_error(
    .boek_labels(list(c("#| label: fig-kaart", "#| label: fig-kaart")), "stof-1"),
    "Dubbele chunklabels"
  )
  testthat::expect_error(
    .boek_labels(list(c("#| label: fig-kaart?", "#| label: fig-kaart!")), "stof-1"),
    "botsen na normalisatie"
  )
})