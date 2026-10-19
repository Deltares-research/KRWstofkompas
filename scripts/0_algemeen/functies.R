#pad naar de nieuwste versie van een bewerkt bestand (<naam>_<jjjjmmdd>.<ext>), gemaakt door 1_data_prep
nieuwste_bestand <- function(map, naam, ext = "parquet") {
  bestanden <- sort(list.files(
    map,
    pattern = paste0("^", naam, "(_\\d{8})?\\.", ext, "$"),
    full.names = TRUE
  ))
  if (length(bestanden) == 0) {
    stop(
      "Geen ",
      naam,
      "_<datum>.",
      ext,
      " in ",
      map,
      "; draai eerst scripts/1_data_prep/00_run_data_prep.R."
    )
  }
  bestanden[length(bestanden)]
}

#nieuwste GIS-laag uit 3_interim (gemaakt door 01c)
lees_gis <- function(naam) {
  readRDS(nieuwste_bestand(paths$interim, naam, ext = "rds"))
}

#hulpfunctie voor het maken van trendcodes voor uniforme kaart en trendconclusies
maak_trend_code_uniform <- function(x) {
  case_when(
    x %in%
      c(
        "opwaarts significant",
        "trend opwaarts"
      ) ~ "Stijgende trend",

    x %in%
      c(
        "neerwaarts significant",
        "trend neerwaarts"
      ) ~ "Dalende trend",

    x %in%
      c(
        "niet significant",
        "geen trend"
      ) ~ "Geen significante trend",

    TRUE ~ "Te weinig metingen voor een trend"
  )
}

trend_kleur <- c(
  "Stijgende trend" = "#d73027",
  "Dalende trend" = "#94cbec",
  "Geen significante trend" = "#E7DD87",
  "Te weinig metingen voor een trend" = "#dddddd"
)
