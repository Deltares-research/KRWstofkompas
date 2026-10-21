# Bereken een tibble en schrijf CSV/RDS plus detailbestanden naar 4_processed.
source(here::here("scripts", "0_algemeen", "paths.R"))
source(here::here("scripts", "0_algemeen", "functies.R"))
source(here::here("scripts", "0_algemeen", "stofindicatoren.R"))

indicatoren_export <- maak_indicatoren_export(paths)
stofindicatoren <- indicatoren_export$indicatoren
stofindicatoren