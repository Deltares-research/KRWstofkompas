# Inladen RIVM-normen
#
# Dit script vormt de ingang voor het inlezen en standaardiseren van de
# RIVM-normen. De concrete leesstap wordt toegevoegd zodra het bronbestand en
# het definitieve kolomformaat beschikbaar zijn.

library(here)
library(readr)
library(readxl)
library(dplyr)
source(here::here("scripts", "paths.R"))


# Brondirectory voor de RIVM-normen.
pad_normen_rivm <- file.path(paths$raw, "rivm_normen")

# Selecteer het meest recent gewijzigde RIVM-bestand.
rivm_xlsx_pattern <- "^RvS_normen_[0-9]{8}T[0-9]{4}\\.xlsx$"

bestanden_normen_rivm <- list.files(
  path = pad_normen_rivm,
  pattern = rivm_xlsx_pattern,
  full.names = TRUE,
  ignore.case = TRUE
)
if (length(bestanden_normen_rivm) == 0L) {
  stop(glue::glue(
    "Er is geen recent RIVM-bestand met deze structuur {rivm_xlsx_pattern} gevonden."
  ))
}

bestand_normen_rivm <- {
  datums_normen_rivm <- as.POSIXct(
    sub(
      "^RvS_normen_([0-9]{8}T[0-9]{4})\\.xlsx$",
      "\\1",
      basename(bestanden_normen_rivm),
      ignore.case = TRUE
    ),
    format = "%Y%m%dT%H%M",
    tz = "UTC"
  )
  bestanden_normen_rivm[which.max(datums_normen_rivm)]
}

print(glue::glue(
  "Inlezen van het meest recente RIVM-bestand: ", bestand_normen_rivm
))

normen_rivm <- readxl::read_excel(bestand_normen_rivm) |>
  janitor::clean_names() |>
  dplyr::mutate(across(where(is.character), ~trimws(.))) |>
  dplyr::mutate(
    waarde = as.numeric(
      dplyr::na_if(
        stringr::str_replace(waarde, ",", "."),
        "NA"
      )
    )
  ) |>
  dplyr::filter(!is.na(waarde) & !is.na(aquo_code)) |>
  dplyr::select(
    stofnaam, cas_nummer, aquo_code, compartiment, norm, norm_code,
    waarde, eenheid, compartiment_code, compartiment_omschrijving,
    compartimentsubgroep_code, grootheid_code, hoedanigheid_code,
    hoedanigheid_omschrijving, waardebewerkingsmethode_code
  )

arrow::write_parquet(
  normen_rivm,
  file.path(paths$external, "normen_rivm.parquet")
)
