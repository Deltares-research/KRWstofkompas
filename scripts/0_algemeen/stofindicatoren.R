# Eén definitie van de indicatoren voor exports, losse rapporten en het boek.
# Pure samenvattingsfuncties kunnen zonder GIS, websites of rapportpackages draaien.
indicator_pct <- function(n, totaal) {
  ifelse(is.na(totaal) | totaal == 0, NA_real_, 100 * n / totaal)
}

indicator_jaar <- function(x) {
  x <- suppressWarnings(as.integer(as.character(x)))
  if (length(x) && any(!is.na(x))) max(x, na.rm = TRUE) else NA_integer_
}

indicator_tekst <- function(x) {
  x <- sort(unique(as.character(x[!is.na(x) & nzchar(as.character(x))])))
  if (length(x)) paste(x, collapse = "; ") else NA_character_
}

vat_toestand_samen <- function(data) {
  jaar <- suppressWarnings(as.integer(as.character(data$Rapportagejaar)))
  laatste <- indicator_jaar(jaar)
  recent <- data[!is.na(jaar) & jaar == laatste, , drop = FALSE]
  beschikbaar <- nrow(recent) > 0L
  tel <- function(x) if (beschikbaar) sum(x, na.rm = TRUE) else NA_integer_
  n <- if (beschikbaar) nrow(recent) else NA_integer_
  uit <- tibble::tibble(
    toestand_jaar = laatste,
    toestand_n_oordelen = n,
    toestand_n_waterlichamen = if (beschikbaar) {
      dplyr::n_distinct(recent$WaterlichaamCode[!is.na(recent$WaterlichaamCode) &
                                                 nzchar(recent$WaterlichaamCode)])
    } else NA_integer_,
    toestand_n_beheerdersoordeel = tel(recent$Beheerdersoordeel == "Ja"),
    toestand_n_zonder_jaar = sum(is.na(jaar)),
    toestand_n_onbekend = tel(is.na(recent$Classificatie) | !recent$Classificatie %in%
      c("Voldoet niet", "Voldoet", "Niet toetsbaar", "Niet van toepassing"))
  )
  categorieen <- c(voldoet_niet = "Voldoet niet", voldoet = "Voldoet",
                   niet_toetsbaar = "Niet toetsbaar", niet_van_toepassing = "Niet van toepassing")
  for (naam in names(categorieen)) {
    aantal <- tel(recent$Classificatie == categorieen[[naam]])
    uit[[paste0("toestand_n_", naam)]] <- aantal
    uit[[paste0("toestand_pct_", naam)]] <- indicator_pct(aantal, n)
  }
  uit
}

vat_trends_samen <- function(data) {
  niveaus <- c("Landelijk", "Stroomgebied", "Waterlichaam", "Meetpunt")
  dplyr::bind_rows(lapply(niveaus, function(niveau) {
    d <- data[!is.na(data$aggregatieniveau) & data$aggregatieniveau == niveau, , drop = FALSE]
    conclusie <- as.character(d$trend_conclusie)
    conclusie[conclusie == "Geen trend" & !is.na(conclusie)] <- "Geen significante trend"
    geldig <- conclusie %in% c("Stijgende trend", "Dalende trend", "Geen significante trend")
    n <- nrow(d)
    stijgend <- sum(conclusie == "Stijgende trend", na.rm = TRUE)
    dalend <- sum(conclusie == "Dalende trend", na.rm = TRUE)
    geen <- sum(conclusie == "Geen significante trend", na.rm = TRUE)
    tibble::tibble(
      aggregatieniveau = niveau, aantal_totaal = n, aantal_trend = sum(geldig),
      aantal_dalend = dalend, aantal_stijgend = stijgend, aantal_geen = geen,
      aantal_onvoldoende = n - sum(geldig),
      percentage_stijgend = indicator_pct(stijgend, sum(geldig)),
      percentage_dalend = indicator_pct(dalend, sum(geldig)),
      percentage_geen = indicator_pct(geen, sum(geldig)),
      conclusie = indicator_tekst(conclusie),
      # Meerdere bronregels per regio blijven zichtbaar; geen willekeurige deduplicatie.
      n_dubbele_regios = if ("regio_omschrijving" %in% names(d)) sum(duplicated(d$regio_omschrijving)) else 0L
    )
  }))
}

vat_emissies_samen <- function(data) {
  jaar <- suppressWarnings(as.integer(as.character(data$Jaar)))
  laatste <- indicator_jaar(jaar)
  uit <- tibble::tibble(emissie_jaar = laatste)
  for (comp in c("riool", "water")) {
    d <- data[!is.na(data$compartiment) & data$compartiment == comp &
                !is.na(jaar) & jaar == laatste, , drop = FALSE]
    eenheid <- indicator_tekst(d$Eenheid)
    geldig <- nrow(d) > 0L && dplyr::n_distinct(d$Eenheid) == 1L &&
      !is.na(eenheid) && nzchar(trimws(eenheid)) &&
      !tolower(trimws(eenheid)) %in% c("onbekend", "unknown", "n/a", "na", "-") &&
      all(is.finite(d$Emissie)) && all(d$Emissie >= 0)
    totaal <- if (geldig) sum(d$Emissie) else NA_real_
    top <- NA_character_
    aandeel <- NA_real_
    if (geldig) {
      sectoren <- dplyr::summarise(d, Emissie = sum(Emissie), .by = Sector)
      grootste <- max(sectoren$Emissie)
      top <- indicator_tekst(sectoren$Sector[sectoren$Emissie == grootste])
      aandeel <- indicator_pct(grootste, totaal)
    }
    prefix <- paste0("emissie_", comp, "_")
    uit[[paste0(prefix, "laatst_beschikbaar_jaar")]] <- indicator_jaar(jaar[data$compartiment == comp])
    uit[[paste0(prefix, "n_regels")]] <- nrow(d)
    uit[[paste0(prefix, "geldig")]] <- geldig
    uit[[paste0(prefix, "totaal")]] <- totaal
    uit[[paste0(prefix, "eenheid")]] <- eenheid
    uit[[paste0(prefix, "top_sector")]] <- top
    uit[[paste0(prefix, "top_sector_pct")]] <- aandeel
  }
  uit
}

indicator_bronbestanden <- function(paths) {
  namen <- c("normen_rivm", "toestand_wkp", "chemtrend_trend_samenvatting_info_data",
             "rekenfactoren_er_cleaned", "emissies_op_riool", "emissies_op_water")
  stats::setNames(lapply(namen, function(naam) nieuwste_bestand(paths$external, naam)), namen)
}

lees_indicator_bronnen <- function(bestanden) {
  lapply(names(bestanden), function(naam) {
    if (naam %in% c("emissies_op_riool", "emissies_op_water")) {
      arrow::read_parquet(bestanden[[naam]], col_select =
        c("Stofcode", "Stof", "Jaar", "Sector", "Subsector", "Emissieoorzaak", "Emissie", "Eenheid"))
    } else arrow::read_parquet(bestanden[[naam]])
  }) |> stats::setNames(names(bestanden))
}

bepaal_stoffen <- function(bronnen) {
  stoffen <- sort(unique(c(as.character(bronnen$toestand_wkp$KRWkwaliteitselementCode),
                          as.character(bronnen$chemtrend_trend_samenvatting_info_data$parameter_code))))
  stoffen <- stoffen[!is.na(stoffen) & nzchar(stoffen)]
  codes <- unique(c(bronnen$emissies_op_riool$Stofcode, bronnen$emissies_op_water$Stofcode))
  er <- bronnen$rekenfactoren_er_cleaned
  tibble::tibble(
    stof = stoffen,
    heeft_toestand = stoffen %in% bronnen$toestand_wkp$KRWkwaliteitselementCode,
    heeft_trend = stoffen %in% bronnen$chemtrend_trend_samenvatting_info_data$parameter_code,
    heeft_emissie = stoffen %in% er$aquo_code[er$gepresenteerde_stof_code %in% codes]
  )
}

selecteer_stofbronnen <- function(stof, bronnen) {
  selecteer <- function(data, kolom, waarden) {
    data[!is.na(data[[kolom]]) & data[[kolom]] %in% waarden, , drop = FALSE]
  }
  er <- selecteer(bronnen$rekenfactoren_er_cleaned, "aquo_code", stof)
  list(
    normen = selecteer(bronnen$normen_rivm, "aquo_code", stof),
    toestand = selecteer(bronnen$toestand_wkp, "KRWkwaliteitselementCode", stof),
    trends = selecteer(bronnen$chemtrend_trend_samenvatting_info_data, "parameter_code", stof),
    emissies = dplyr::bind_rows(
      riool = selecteer(bronnen$emissies_op_riool, "Stofcode", unique(er$gepresenteerde_stof_code)),
      water = selecteer(bronnen$emissies_op_water, "Stofcode", unique(er$gepresenteerde_stof_code)),
      .id = "compartiment"
    )
  )
}

bereken_stofindicatoren <- function(stof, data) {
  trends <- vat_trends_samen(data$trends)
  uit <- dplyr::bind_cols(
    tibble::tibble(
      stof = stof, stofnaam = indicator_tekst(data$normen$stofnaam),
      cas_nummer = indicator_tekst(data$normen$cas_nummer),
      heeft_toestand = nrow(data$toestand) > 0L,
      heeft_trend = nrow(data$trends) > 0L,
      heeft_emissie = nrow(data$emissies) > 0L,
      normen_n = nrow(data$normen),
      normen_compartimenten = indicator_tekst(data$normen$compartiment),
      trend_landelijk = trends$conclusie[trends$aggregatieniveau == "Landelijk"]
    ),
    vat_toestand_samen(data$toestand), vat_emissies_samen(data$emissies)
  )
  for (i in seq_len(nrow(trends))) {
    for (naam in setdiff(names(trends), c("aggregatieniveau", "conclusie"))) {
      waarde <- trends[[naam]][i]
      if (trends$aantal_totaal[i] == 0L) waarde <- NA_real_
      suffix <- sub("^aantal_", "n_", naam)
      uit[[paste0("trend_", tolower(trends$aggregatieniveau[i]), "_", suffix)]] <- waarde
    }
  }
  uit
}

# Voor een los rapport: lees een voorbereid resultaat of bereken uitsluitend deze stof.
lees_stofindicatoren <- function(stof, bestand = NULL, bronbestanden = NULL) {
  if (!is.null(bestand) && nzchar(bestand)) {
    data <- readRDS(bestand)
    uit <- data[data$stof == stof & !is.na(data$stof), , drop = FALSE]
    if (nrow(uit) != 1L) stop("Geen unieke indicatorenrij voor: ", stof)
    return(uit)
  }
  if (is.null(bronbestanden)) bronbestanden <- indicator_bronbestanden(paths)
  # Filter vóór collect voor zelfstandig renderen.
  bronnen <- lapply(bronbestanden, function(p) arrow::open_dataset(p))
  normen <- dplyr::collect(dplyr::filter(bronnen$normen_rivm, aquo_code == stof))
  toestand <- dplyr::collect(dplyr::filter(bronnen$toestand_wkp, KRWkwaliteitselementCode == stof))
  trends <- dplyr::collect(dplyr::filter(bronnen$chemtrend_trend_samenvatting_info_data, parameter_code == stof))
  er <- dplyr::collect(dplyr::filter(bronnen$rekenfactoren_er_cleaned, aquo_code == stof))
  codes <- unique(er$gepresenteerde_stof_code)
  emissies <- dplyr::bind_rows(
    riool = dplyr::collect(dplyr::select(dplyr::filter(bronnen$emissies_op_riool, Stofcode %in% codes),
      Stofcode, Stof, Jaar, Sector, Subsector, Emissieoorzaak, Emissie, Eenheid)),
    water = dplyr::collect(dplyr::select(dplyr::filter(bronnen$emissies_op_water, Stofcode %in% codes),
      Stofcode, Stof, Jaar, Sector, Subsector, Emissieoorzaak, Emissie, Eenheid)),
    .id = "compartiment"
  )
  bereken_stofindicatoren(stof, list(normen = normen, toestand = toestand, trends = trends, emissies = emissies))
}

maak_indicatoren_export <- function(paths, selectie = NULL) {
  bestanden <- indicator_bronbestanden(paths)
  md5 <- tools::md5sum(unlist(bestanden))
  bronnen <- lees_indicator_bronnen(bestanden)
  stoffen <- bepaal_stoffen(bronnen)
  if (!is.null(selectie)) {
    ontbreekt <- setdiff(selectie, stoffen$stof)
    if (length(ontbreekt)) stop("Onbekende stofcodes in selectie: ", paste(ontbreekt, collapse = ", "))
    stoffen <- stoffen[stoffen$stof %in% selectie, , drop = FALSE]
  }
  if (!nrow(stoffen)) stop("Geen stoffen met toestand- of trendgegevens.")
  data <- lapply(stoffen$stof, selecteer_stofbronnen, bronnen = bronnen)
  indicatoren <- dplyr::bind_rows(Map(bereken_stofindicatoren, stoffen$stof, data))
  if (anyDuplicated(indicatoren$stof)) stop("Indicatoren bevatten dubbele stofcodes.")
  run_id <- paste0(format(Sys.time(), "%Y%m%dT%H%M%S"), "-", Sys.getpid(), "-", basename(tempfile()))
  export_dir <- file.path(paths$processed, "stofindicatoren", run_id)
  dir.create(export_dir, recursive = TRUE, showWarnings = FALSE)
  saveRDS(indicatoren, file.path(export_dir, "stofindicatoren.rds"))
  readr::write_csv(indicatoren, file.path(export_dir, "stofindicatoren.csv"), na = "")
  # Detailbestanden bewaren alle bronparameters, zonder verlies door verbreding.
  for (naam in c("normen", "toestand", "trends", "emissies")) {
    detail <- dplyr::bind_rows(lapply(seq_along(data), function(i) {
      dplyr::mutate(data[[i]][[naam]], stof = stoffen$stof[i], .before = 1)
    }))
    readr::write_csv(detail, file.path(export_dir, paste0(naam, "_details.csv")), na = "")
  }
  woordenboek <- tibble::tibble(
    kolom = names(indicatoren),
    type = vapply(indicatoren, function(x) class(x)[1], character(1)),
    eenheid = ifelse(grepl("pct|percentage", names(indicatoren)), "% (0–100)",
                     ifelse(grepl("_n_|normen_n", names(indicatoren)), "aantal", "zie definitie")),
    definitie = vapply(names(indicatoren), indicator_definitie, character(1))
  )
  readr::write_csv(woordenboek, file.path(export_dir, "datadictionary.csv"))
  if (!identical(unname(md5), unname(tools::md5sum(unlist(bestanden))))) {
    stop("Bronbestanden gewijzigd tijdens berekening; herhaal de export.")
  }
  saveRDS(list(bestanden = bestanden, md5 = md5, aangemaakt = Sys.time(), stoffen = stoffen),
          file.path(export_dir, "provenance.rds"))
  readr::write_csv(tibble::tibble(bron = names(bestanden), bestand = unlist(bestanden), md5 = unname(md5)),
                   file.path(export_dir, "bronbestanden.csv"))
  list(indicatoren = indicatoren, stoffen = stoffen, bestanden = bestanden, export_dir = export_dir)
}

indicator_definitie <- function(kolom) {
  if (grepl("^toestand_", kolom)) {
    return(paste(kolom, "— meest recente geldige Rapportagejaar; percentages over alle oordelen, niet waterlichamen; n_zonder_jaar over alle jaren."))
  }
  if (grepl("^trend_", kolom)) {
    return(paste(kolom, "— CHEMtrend-bronregels vóór GIS-joins; percentages over geldige trends (stijgend, dalend, niet significant); n_dubbele_regios signaleert herhaalde regio's."))
  }
  if (grepl("^emissie_", kolom)) {
    return(paste(kolom, "— laatste ER-jaar over beide compartimenten; totaal in opgegeven eenheid/jaar; geldig vereist één bekende eenheid en volledige niet-negatieve waarden; top_sector_pct geldt per gedeelde eerste plaats. Compartimenten niet optellen."))
  }
  paste(kolom, "— identificatie, bronbeschikbaarheid of lokale RIVM-normen; normen_n telt bronregels. Ontbrekende getallen zijn NA, geen nul.")
}