# Inlezen en formatteren van CHEMtrend-resultaten (project 012-Chemtrend).
#
# Invoer (map_chemtrend)                                Uitvoer                                         Gebruikt in
# ----------------------------------------------------  ----------------------------------------------  ------------------------------
# aquodom (online)                                      2_external/aquo_parameters_<datum>                parameternamen hieronder
# bewerkt/trend_info_per_{parameter,stroomgebied,       2_external/chemtrend_trend_samenvatting_          trendconclusies, tabel en kaarten
#   waterlichaam,locatie}.csv                             info_data_<datum>                               (03_trends) en stoffenlijst
# tussen/02_data_for_trend_analysis_vanaf_2009.parquet  3_interim/chemtrend_meetpunten_<datum>           locaties meetpunten op de kaart
# bewerkt/03B_data_trend_ats_info_vanaf_2009.parquet    3_interim/chemtrend_lowline_meetpunt_<datum>     grijze lijnen landelijke trendfiguur
#                                                       3_interim/chemtrend_lowess_landelijk_<datum>     rode lijnen landelijke trendfiguur
#                                                         (p0, p25, p75; lang formaat)

if (!exists("paths")) {
  source(here::here("scripts", "0_algemeen", "setup.R"))
}

map_chemtrend <- "P:/sito-wbk-07/2026/012-Chemtrend/R/CHEMTrend/data"

# 1. Aquo-parameters (codes en namen) ------------------------------------------

parameters <- aquodom::dom('Parameter')

arrow::write_parquet(
  parameters,
  file.path(
    paths$external,
    paste0("aquo_parameters_", settings$run_date, ".parquet")
  )
)

# 2. Trendconclusies per aggregatieniveau --------------------------------------
# Eén tabel met per stof en regio (landelijk, stroomgebied, waterlichaam, meetpunt)
# de trendconclusie, mediane waarde en relatieve trend per decennium.

trend_info_landelijk <-
  readr::read_csv2(
    file.path(map_chemtrend, "bewerkt", "trend_info_per_parameter.csv")
  ) |>
  mutate(
    trend_conclusie = maak_trend_code_uniform(trend_conclusie),
    trend_conclusie = replace_na(
      trend_conclusie,
      "Te weinig metingen voor een trend"
    ),
    aggregatieniveau = "Landelijk",
    regio_omschrijving = "Nederland",
  ) |>
  left_join(
    parameters |> select(parameter_code = codes, parameter_naam = omschrijving),
    by = "parameter_code"
  )

trend_info_per_stroomgebied <-
  readr::read_csv2(
    file.path(map_chemtrend, "bewerkt", "trend_info_per_stroomgebied.csv")
  ) |>
  mutate(
    trend_conclusie = maak_trend_code_uniform(trend_conclusie),
    trend_conclusie = replace_na(
      trend_conclusie,
      "Te weinig metingen voor een trend"
    ),
    aggregatieniveau = "Stroomgebied"
  ) |>
  left_join(
    parameters |> select(parameter_code = codes, parameter_naam = omschrijving),
    by = "parameter_code"
  )

trend_info_per_waterlichaam <-
  readr::read_csv2(
    file.path(map_chemtrend, "bewerkt", "trend_info_per_waterlichaam.csv")
  ) |>
  mutate(
    trend_conclusie = maak_trend_code_uniform(trend_conclusie),
    trend_conclusie = replace_na(
      trend_conclusie,
      "Te weinig metingen voor een trend"
    ),
    aggregatieniveau = "Waterlichaam"
  ) |>
  left_join(
    parameters |> select(parameter_code = codes, parameter_naam = omschrijving),
    by = "parameter_code"
  )

trend_info_meetpunt <-
  readr::read_csv2(
    file.path(map_chemtrend, "bewerkt", "trend_info_per_locatie.csv")
  ) |>
  left_join(
    trend_info_landelijk |>
      select(
        parameter_code,
        parameter_naam,
        eenheid_code,
        hoedanigheid_code,
        compartiment_code
      ),
    by = "parameter_code"
  ) |>
  mutate(
    trend_conclusie = maak_trend_code_uniform(skendall_trend),
    trend_conclusie = replace_na(
      trend_conclusie,
      "Te weinig metingen voor een trend"
    ),
    aggregatieniveau = "Meetpunt",
    regio_omschrijving = meetpunt_code_nieuw
  )

chemtrend_data <- dplyr::bind_rows(
  trend_info_landelijk,
  trend_info_per_stroomgebied,
  trend_info_per_waterlichaam,
  trend_info_meetpunt
) |>
  select(
    aggregatieniveau,
    regio_omschrijving,
    parameter_naam,
    parameter_code,
    eenheid_code,
    hoedanigheid_code,
    compartiment_code,
    trend_conclusie,
    median_waarde,
    relatieve_trend_decenium,
  )

arrow::write_parquet(
  chemtrend_data,
  file.path(
    paths$external,
    paste0(
      "chemtrend_trend_samenvatting_info_data_",
      settings$run_date,
      ".parquet"
    )
  )
)

# 3. Meetpuntlocaties (x/y in RD) ----------------------------------------------
# Alleen de unieke locaties; de volledige meetdata is niet nodig in het rapport.
chemtrend_meetpunten <-
  arrow::open_dataset(
    file.path(
      map_chemtrend,
      "tussen",
      "02_data_for_trend_analysis_vanaf_2009.parquet"
    )
  ) |>
  distinct(meetpunt_code_nieuw, x_rd, y_rd) |>
  collect()

arrow::write_parquet(
  chemtrend_meetpunten,
  file.path(
    paths$interim,
    paste0("chemtrend_meetpunten_", settings$run_date, ".parquet")
  )
)

#locatie specifieke en landelijke trenddata ophalen direct vanuit de database en exporteren naar parquet bestanden

if (!exists("paths")) {
  source(here::here("scripts", "0_algemeen", "setup.R"))
}

library(DBI)
library(RPostgres)

con <- dbConnect(
  Postgres(),
  host = "c-oet33628.directory.intra",
  port = 5432,
  dbname = "waterkwaliteit",
  user = "eck",
  password = rstudioapi::askForPassword("PostgreSQL password")
)

# pass con into the function
export_all_chemtrend_parquet(
  con = con,
  out_dir = file.path(paths$raw, "chemtrend/chemtrend_parquet_all")
)

DBI::dbDisconnect(con)
