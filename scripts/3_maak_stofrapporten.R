# Stap 3: maak voor elke stof een stofrapport (scripts/2_rapport_templates/stofrapport.qmd)
source(here::here("scripts", "0_algemeen", "setup.R"))

indicatoren_export <- maak_indicatoren_export(paths)
stofindicatoren <- indicatoren_export$indicatoren
stoffen <- indicatoren_export$stoffen

output_dir <- file.path(paths$output, "stof_rapporten")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

qmd_file <- here::here("scripts", "2_rapport_templates", "stofrapport.qmd")

mislukt <- character()

for (i in seq_len(nrow(stoffen))) {
  stof <- stoffen$stof[i]
  message("Maak rapport voor: ", stof, " (", i, "/", nrow(stoffen), ")")
  bestandsnaam <- paste0(gsub("[^A-Za-z0-9_.-]", "_", stof), ".html")

  # Quarto kan niet direct naar een andere schijf (P:) renderen; daarom eerst naast de template
  tryCatch(
    {
      render_stoffen_quarto(
        input = qmd_file,
        output_file = bestandsnaam,
        execute_params = list(
          stof = stof,
          heeft_toestand = stoffen$heeft_toestand[i],
          heeft_trend = stoffen$heeft_trend[i],
          heeft_emissie = stoffen$heeft_emissie[i],
          indicatoren_bestand = file.path(indicatoren_export$export_dir, "stofindicatoren.rds"),
          bronbestanden = indicatoren_export$bestanden
        ),
        quiet = TRUE
      )
      tijdelijk <- file.path(dirname(qmd_file), bestandsnaam)
      file.copy(
        tijdelijk,
        file.path(output_dir, bestandsnaam),
        overwrite = TRUE
      )
      # Bewaar de lokale render ook voor inspectie; geen automatische verwijdering.
    },
    error = function(e) {
      message("Mislukt voor ", stof, ": ", conditionMessage(e))
      mislukt <<- c(mislukt, stof)
    }
  )
}

if (length(mislukt) > 0) {
  message("Rapporten mislukt voor: ", paste(mislukt, collapse = ", "))
}
