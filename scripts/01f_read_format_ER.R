#inladen emissieregistratie data
#vanaf de site is het een excel. eenmalig inladen en omzetten naar sneller format.
# emissies_op_water <-
#   readxl::read_excel(
#   "P:/emissieregistratie/2_emissieberekeningen/algemene_datafolder/ER1990_2024/eindexport_van_publieke_site/ER_DataExport-2026-07-13-115035.xlsx", sheet = "Emissies"
#     )
# emissies_op_riool <-
#   readxl::read_excel(
#   "P:/emissieregistratie/2_emissieberekeningen/algemene_datafolder/ER1990_2024/eindexport_van_publieke_site/ER_DataExport-2026-07-13-115305.xlsx", sheet = "Emissies"
#     )

# #schrijf weg als parquet eenmalig om het hierna hiermee in te lezen
#   arrow::write_parquet(
#   emissies_op_water,
#   "data/2_external/emissies_op_water.parquet"
# )
#   arrow::write_parquet(
#   emissies_op_riool,
#   "data/2_external/emissies_op_riool.parquet"
# )

emissies_op_water <- arrow::read_parquet(
  "data/2_external/emissies_op_water.parquet"
)

emissies_op_riool <- arrow::read_parquet(
  "data/2_external/emissies_op_riool.parquet"
)

koppeltabel_aquo_er <- readxl::read_excel(
  "P:/emissieregistratie/2_emissieberekeningen/algemene_datafolder/ER1990_2024/stofcodes_aquo_er_2024_20250613.xlsx"
)
