# Inladen RIVM-normen
#
# Dit script vormt de ingang voor het inlezen en standaardiseren van de
# RIVM-normen. De concrete leesstap wordt toegevoegd zodra het bronbestand en
# het definitieve kolomformaat beschikbaar zijn.

library(here)
library(readr)
library(readxl)
library(dplyr)

# Zorg dat paden onafhankelijk zijn van de huidige werkdirectory.
project_root <- here::here()

# Brondirectory en uitvoerbestand voor de gestandaardiseerde normen.
pad_normen_rivm <- here::here(
  "data",
  "1_raw",
  "normen",
  "RIVM"
)

pad_normen_rivm_bewerkt <- here::here(
  "data",
  "2_external",
  "normen_rivm.csv"
)

# Stel dit in op de naam van het ontvangen RIVM-bestand.
bestand_normen_rivm <- file.path(
  pad_normen_rivm,
  "normen_RIVM.xlsx"
)

# Controleer de configuratie voordat de leesstap wordt toegevoegd.
if (!dir.exists(pad_normen_rivm)) {
  warning(
    "De RIVM-brondirectory bestaat nog niet: ",
    pad_normen_rivm,
    call. = FALSE
  )
}

if (file.exists(bestand_normen_rivm)) {
  extensie <- tools::file_ext(bestand_normen_rivm)

  normen_rivm_raw <- switch(
    tolower(extensie),
    xls = readxl::read_excel(bestand_normen_rivm),
    xlsx = readxl::read_excel(bestand_normen_rivm),
    csv = readr::read_csv(bestand_normen_rivm, show_col_types = FALSE),
    csv2 = readr::read_csv2(bestand_normen_rivm, show_col_types = FALSE),
    stop(
      "Bestandstype voor RIVM-normen wordt niet ondersteund: .",
      extensie,
      call. = FALSE
    )
  )
} else {
  normen_rivm_raw <- NULL
  warning(
    "Het geconfigureerde RIVM-bronbestand bestaat nog niet: ",
    bestand_normen_rivm,
    call. = FALSE
  )
}