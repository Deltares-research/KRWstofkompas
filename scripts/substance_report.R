library(quarto)
library(readr)
library(dplyr)
library(here)
source("scripts/workflow_to_report/functies.R")

# Zorg dat we vanuit de project-root werken
setwd(
  here()
)


# Stoffen ophalen
trend_info_landelijk <-
  readr::read_csv2(
    here("data/bewerkt/trend_info_per_parameter.csv")
  )


stoffen <-
  trend_info_landelijk |>
  arrange(parameter_code) |>
  distinct(parameter_code) |>
  pull(parameter_code)


# QMD locatie
qmd_file <-
  here(
    "scripts",
    "workflow_to_report",
    "make_overview_per_substance.qmd"
  )


# Render alle stoffen

for (stof in stoffen) {
  message("Maak rapport voor: ", stof)

  quarto_render(
    input = qmd_file,

    execute_params = list(
      stof = stof
    ),

    output_file = paste0(stof, ".html")
  )
}


overzicht_alle_stoffen <-
  purrr::map_dfr(stoffen, function(stof) {
    ## maak landelijk, stroomgebied,
    ## waterlichaam en meetpunt

    overzicht_trend <-
      maak_overzicht_trend(
        landelijk,
        stroomgebied,
        waterlichaam,
        meetpunt
      )

    overzicht_trend
  })
