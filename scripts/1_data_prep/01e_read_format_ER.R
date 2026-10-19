#inladen emissieregistratie data (excel-export van de publieke site) en wegschrijven als parquet
if (!exists("paths")) {
  source(here::here("R", "setup.R"))
}

map_er <- "P:/emissieregistratie/2_emissieberekeningen/algemene_datafolder/ER1990_2024"

er_bestanden <- c(
  emissies_op_water = "eindexport_van_publieke_site/ER_DataExport-2026-07-13-115035.xlsx",
  emissies_op_riool = "eindexport_van_publieke_site/ER_DataExport-2026-07-13-115305.xlsx"
)

for (naam in names(er_bestanden)) {
  readxl::read_excel(
    file.path(map_er, er_bestanden[[naam]]),
    sheet = "Emissies"
  ) |>
    arrow::write_parquet(
      file.path(
        paths$external,
        paste0(naam, "_", settings$run_date, ".parquet")
      )
    )
}

readxl::read_excel(file.path(map_er, "stofcodes_aquo_er_2024_20250613.xlsx")) |>
  arrow::write_parquet(
    file.path(
      paths$external,
      paste0("koppeltabel_aquo_er_", settings$run_date, ".parquet")
    )
  )
