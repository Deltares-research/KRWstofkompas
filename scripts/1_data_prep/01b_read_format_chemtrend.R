# inladen CHEMtrend: trendconclusies per aggregatieniveau, meetpuntlocaties en lowess-trendlijnen
if (!exists("paths")) {
  source(here::here("scripts", "0_algemeen", "setup.R"))
}

map_chemtrend <- "P:/sito-wbk-07/2026/012-Chemtrend/R/CHEMTrend/data"

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

# meetpuntlocaties voor de kaarten; de volledige meetdata is niet nodig in het rapport
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

lowess_bestanden <- c(
  landelijk = "04B_data_trend_ats_landelijk_vanaf_2009.csv",
  stroomgebied = "06B_data_trend_ats_stroomgebied_vanaf_2009.csv",
  waterlichaam = "05B_data_trend_ats_waterbeheerder_vanaf_2009.csv"
)

for (niveau in names(lowess_bestanden)) {
  readr::read_csv(
    file.path(map_chemtrend, "bewerkt", lowess_bestanden[[niveau]]),
    show_col_types = FALSE
  ) |>
    arrow::write_parquet(
      file.path(
        paths$interim,
        paste0("chemtrend_lowess_", niveau, "_", settings$run_date, ".parquet")
      )
    )
}
