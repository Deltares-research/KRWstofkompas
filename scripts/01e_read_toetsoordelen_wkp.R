input_dir <- "P:/sito-wbk-07/2026/002-KRW strategie/data/1_raw/toetsresultaten wkp/toestand_waterlichamen"
output_dir <- "P:/sito-wbk-07/2026/002-KRW strategie/data/2_external"

bestanden <- list.files(
  input_dir,
  pattern = "^WKP_KRW-toestandsoordelen-beknopt_Nederland_[0-9]{4}_.*\\.csv$",
  full.names = TRUE
)

if (length(bestanden) == 0L) {
  stop("Geen bestanden met toestandsoordelen gevonden in: ", input_dir)
}

toestand_wkp <- dplyr::bind_rows(lapply(bestanden, function(bestand) {
  gegevens <- read.csv2(
    bestand,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    colClasses = "character"
  )
  # Bewaar het verslagjaar en de herkomst van iedere rij.
  gegevens$verslagjaar <- as.integer(sub(
    "^WKP_KRW-toestandsoordelen-beknopt_Nederland_([0-9]{4})_.*$",
    "\\1",
    basename(bestand)
  ))
  gegevens$bronbestand <- basename(bestand)
  gegevens
}))

arrow::write_parquet(
  toestand_wkp,
  file.path(output_dir, "toestand_wkp.parquet")
)
