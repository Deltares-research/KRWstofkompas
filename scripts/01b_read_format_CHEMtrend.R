# inladen chemtrend data
source(here::here("scripts", "functies.R"))
source(here::here("scripts", "paths.R"))

parameters <- aquodom::dom('Parameter')

arrow::write_parquet(
  parameters,
  file.path(
    paths$external,
    paste0("aquo_parameters_", settings$run_date, ".parquet")
  )
)

trend_info_landelijk <-
  readr::read_csv2(
    "P:/sito-wbk-07/2026/012-Chemtrend/R/CHEMTrend/data/bewerkt/trend_info_per_parameter.csv"
  ) |>
  mutate(
    trend_kleur_code = maak_trend_code_uniform(trend_conclusie),
    trend_kleur_code = replace_na(
      trend_kleur_code,
      "Te weinig metingen voor een trend"
    ),
    aggregatieniveau = "Landelijk",
    regio_omschrijving = "Nederland"
  ) |>
  left_join(
    parameters |> select(parameter_code = codes, parameter_naam = omschrijving),
    by = "parameter_code"
  )

trend_info_per_stroomgebied <-
  readr::read_csv2(
    "P:/sito-wbk-07/2026/012-Chemtrend/R/CHEMTrend/data/bewerkt/trend_info_per_stroomgebied.csv"
  ) |>
  mutate(
    trend_kleur_code = maak_trend_code_uniform(trend_conclusie),
    trend_kleur_code = replace_na(
      trend_kleur_code,
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
    "P:/sito-wbk-07/2026/012-Chemtrend/R/CHEMTrend/data/bewerkt/trend_info_per_waterlichaam.csv"
  ) |>
  mutate(
    trend_kleur_code = maak_trend_code_uniform(trend_conclusie),
    trend_kleur_code = replace_na(
      trend_kleur_code,
      "Te weinig metingen voor een trend"
    ),
    aggregatieniveau = "Waterlichaam"
  ) |>
  left_join(
    parameters |> select(parameter_code = codes, parameter_naam = omschrijving),
    by = "parameter_code"
  )

chemtrend_data <- dplyr::bind_rows(
  trend_info_landelijk,
  trend_info_per_stroomgebied,
  trend_info_per_waterlichaam
)

arrow::write_parquet(
  chemtrend_data,
  file.path(
    paths$external,
    paste0("chemtrend_data_formatted", settings$run_date, ".parquet")
  )
)
