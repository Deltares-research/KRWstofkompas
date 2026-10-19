# Stap 1: ruwe data inlezen, formatteren en wegschrijven naar data/2_external en 3_interim.
# Alle uitvoer krijgt de datum van de run (settings$run_date); de rapporten lezen de nieuwste versie.
source(here::here("scripts", "0_algemeen", "setup.R"))

scripts <- c(
  "01a_read_format_normen_RIVM.R",
  "01b_read_format_chemtrend.R",
  "01c_read_gis_data.R",
  "01d_read_toetsoordelen_wkp.R",
  "01e_read_format_ER.R"
)

for (script in scripts) {
  message("Draai ", script)
  duur <- system.time(
    source(here::here("scripts", "1_data_prep", script), local = new.env())
  )
  message("  klaar in ", round(duur[["elapsed"]]), " s")
}
