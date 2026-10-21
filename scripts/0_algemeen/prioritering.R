# Criteria uit Projectplan KRW stoffen 2026, onderdeel
# 'Borging, actualisatie en kennisproducten'. Het plan specificeert geen gewichten.
project_prioriteringskader <- function() {
  tibble::tibble(
    criterium = c("normoverschrijding", "trend_niet_afnemend", "ruimtelijke_impact",
                  "onzekerheid_kennisleemte", "beleidsurgentie", "handelingsperspectief"),
    omschrijving = c("Frequentie en ernst van normoverschrijdingen", "Niet-afnemende trend",
                     "Ruimtelijke impact", "Onzekerheid en kennisleemte", "Beleidsurgentie",
                     "Handelingsperspectief"),
    gewicht = rep(NA_real_, 6),
    gewicht_status = "Niet vastgesteld in projectplan",
    beslisregel_status = "Drempels, scores en aggregatie niet vastgesteld",
    brononderdeel = "Borging, actualisatie en kennisproducten"
  )
}

# Geen schijnprecisie: een onderbouwingsmatrix, geen onvolledige totaalscore.
maak_projectprioritering <- function(indicatoren) {
  kader <- project_prioriteringskader()
  dplyr::bind_rows(lapply(seq_len(nrow(indicatoren)), function(i) {
    s <- indicatoren[i, , drop = FALSE]
    uit <- kader
    uit$stof <- s$stof
    uit$status <- c("Ontbreekt", if (isTRUE(s$heeft_trend)) "Deels beschikbaar" else "Ontbreekt",
                    "Deels beschikbaar", "Deels beschikbaar", "Ontbreekt", "Ontbreekt")
    uit$onderbouwing <- c(
      "Toestandsbeoordelingen beschikbaar waar gedekt; geen frequentie of ernst van normoverschrijdingen uit meetwaarden. Geen vervanging door percentage voldoet niet.",
      if (isTRUE(s$heeft_trend)) {
        paste0("CHEMtrend-uitkomsten; landelijk: ", ifelse(is.na(s$trend_landelijk), "onbekend", s$trend_landelijk),
               ". Geen significante trend is geen bewijs voor een stabiele concentratie. Nog geen beslisregel voor niet-afnemend.")
      } else "Geen CHEMtrend-uitkomsten voor deze stof.",
      "Kaarten en regionale gegevens zijn waar beschikbaar context; nog geen impactmaat, gebiedsweging of complete dekking.",
      paste0("Bronbeschikbaarheid: toestand=", s$heeft_toestand, "; trends=", s$heeft_trend,
             "; ER=", s$heeft_emissie, ". Geen volledige onzekerheidsanalyse. Arcadis/Aveco de Bondt nog niet geïntegreerd."),
      "Stofspecifieke beleidsurgentie en afstemming met RWS WVL/IenW nog niet vastgelegd; niet afgeleid uit stofcode of emissiemassa.",
      "ER-sectoren/routes zijn broncontext, geen maat voor uitvoerbaarheid of effect van maatregelen. Externe brononderzoeken en maatregelenkennis ontbreken nog."
    )
    uit$prioritering_status <- "Onvolledig kader; geen totaalscore of rangorde"
    dplyr::relocate(uit, stof)
  }))
}

exporteer_projectprioritering <- function(export, projectplan) {
  if (!file.exists(projectplan)) stop("Projectplan niet gevonden: ", projectplan)
  readr::write_csv(project_prioriteringskader(), file.path(export$export_dir, "prioriteringskader.csv"), na = "")
  readr::write_csv(maak_projectprioritering(export$indicatoren),
                   file.path(export$export_dir, "prioritering.csv"), na = "")
  readr::write_csv(tibble::tibble(
    document = basename(projectplan), md5 = unname(tools::md5sum(projectplan)),
    geraadpleegd = as.character(Sys.Date()),
    onderdelen = "Doel en beoogd resultaat; Scope en afbakening; Werkwijze; Borging, actualisatie en kennisproducten; Deliverables",
    gewichten = "Geen numerieke gewichten of scoreformule in geraadpleegde document"
  ), file.path(export$export_dir, "projectplan_bron.csv"))
  invisible(export)
}