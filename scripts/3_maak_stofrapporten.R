# Stap 3: maak voor elke stof een stofrapport (scripts/2_rapport_templates/stofrapport.qmd)
source(here::here("scripts", "0_algemeen", "setup.R"))

stoffen_toestand <- arrow::read_parquet(
  nieuwste_bestand(paths$external, "toestand_wkp"),
  col_select = "KRWkwaliteitselementCode"
) |>
  distinct(stof = KRWkwaliteitselementCode)

stoffen_trend <- arrow::read_parquet(
  nieuwste_bestand(paths$external, "chemtrend_trend_samenvatting_info_data"),
  col_select = "parameter_code"
) |>
  distinct(stof = parameter_code)

stoffen <- full_join(
  stoffen_toestand |> mutate(heeft_toestand = TRUE),
  stoffen_trend |> mutate(heeft_trend = TRUE),
  by = "stof"
) |>
  filter(!is.na(stof), stof != "") |>
  mutate(across(c(heeft_toestand, heeft_trend), \(x) coalesce(x, FALSE))) |>
  arrange(stof)

output_dir <- file.path(paths$output, "stof_rapporten")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

qmd_file <- here::here("scripts", "2_rapport_templates", "stofrapport.qmd")

mislukt <- character()

for (i in seq_len(nrow(stoffen))) {
  stof <- stoffen$stof[i]
  message("Maak rapport voor: ", stof, " (", i, "/", nrow(stoffen), ")")

  tryCatch(
    quarto::quarto_render(
      input = qmd_file,
      output_file = paste0(gsub("[^A-Za-z0-9_.-]", "_", stof), ".html"),
      execute_params = list(
        stof = stof,
        heeft_toestand = stoffen$heeft_toestand[i],
        heeft_trend = stoffen$heeft_trend[i]
      ),
      quarto_args = c("--output-dir", output_dir),
      quiet = TRUE
    ),
    error = function(e) {
      message("Mislukt voor ", stof, ": ", conditionMessage(e))
      mislukt <<- c(mislukt, stof)
    }
  )
}

if (length(mislukt) > 0) {
  message("Rapporten mislukt voor: ", paste(mislukt, collapse = ", "))
}
