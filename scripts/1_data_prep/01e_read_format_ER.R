#inladen emissieregistratie data (excel-export van de publieke site) en wegschrijven als parquet
if (!exists("paths")) {
  source(here::here("scripts", "0_algemeen", "setup.R"))
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
#maak koppeltabel van geregistreerde stoffen naar gepresenteerde stoffen (ER-rekenfactoren) met aquo
parameters <- aquodom::dom('Parameter')

hoi <- readxl::read_excel(
  file.path(map_er, "ER-Rekenfactoren-2026-03-02_122535-dtt70.xlsx"),
  sheet = "Data"
) |>
  dplyr::slice(-1) |>
  dplyr::rename(
    dataset_id = 1,
    dataset_naam = 2,
    geregistreerde_stof_code = 3,
    geregistreerde_stof_naam = 4,
    geregistreerde_stof_cas = 5,
    geregistreerde_stof_prioritair = 6,
    rekenfactor = 7,
    gepresenteerde_stof_code = 8,
    gepresenteerde_stof_naam = 9
  ) |>
  left_join(
    parameters |>
      dplyr::select(aquo_code = codes, aquo_naam = omschrijving, casnummer),
    by = c("geregistreerde_stof_cas" = "casnummer")
  ) |>
  dplyr::mutate(
    aquo_code = dplyr::case_when(
      geregistreerde_stof_naam == "Naftaleen" ~ "Naf",
      geregistreerde_stof_naam == "Mecoprop" ~ "MCCP",
      geregistreerde_stof_naam == "Diclofenac" ~ "Dclofnc",
      geregistreerde_stof_naam == "Antimoonverb. als Sb" ~ "Sb",
      geregistreerde_stof_naam == "Arseenverb. als As" ~ "As",
      geregistreerde_stof_naam == "Chroomverb.(totaal) als Cr" ~ "Cr",
      geregistreerde_stof_naam == "Cadmiumverb. als Cd" ~ "Cd",
      geregistreerde_stof_naam == "Nikkelverb. als Ni" ~ "Ni",
      geregistreerde_stof_naam == "Zinkverb. als Zn" ~ "Zn",
      geregistreerde_stof_naam == "Koperverb. als Cu" ~ "Cu",
      geregistreerde_stof_naam == "Loodverb. als Pb" ~ "Pb",
      geregistreerde_stof_naam == "Kwikverb. als Hg" ~ "Hg",
      geregistreerde_stof_naam == "Seleenverb. als Se" ~ "Se",

      .default = aquo_code
    ),
    aquo_naam = dplyr::case_when(
      geregistreerde_stof_naam == "Naftaleen" ~ "naftaleen",
      geregistreerde_stof_naam == "Mecoprop" ~ "mecoprop",
      geregistreerde_stof_naam == "Diclofenac" ~ "diclofenac",
      geregistreerde_stof_naam == "Antimoonverb. als Sb" ~ "antimoon",
      geregistreerde_stof_naam == "Arseenverb. als As" ~ "arseen",
      geregistreerde_stof_naam == "Chroomverb.(totaal) als Cr" ~ "chroom",
      geregistreerde_stof_naam == "Cadmiumverb. als Cd" ~ "cadmium",
      geregistreerde_stof_naam == "Nikkelverb. als Ni" ~ "nikkel",
      geregistreerde_stof_naam == "Zinkverb. als Zn" ~ "zink",
      geregistreerde_stof_naam == "Koperverb. als Cu" ~ "koper",
      geregistreerde_stof_naam == "Loodverb. als Pb" ~ "lood",
      geregistreerde_stof_naam == "Kwikverb. als Hg" ~ "kwik",
      geregistreerde_stof_naam == "Seleenverb. als Se" ~ "seleen",

      .default = aquo_naam
    )
  ) |>
  dplyr::filter(
    rekenfactor == 1,
    !is.na(aquo_code),
    !gepresenteerde_stof_naam %in%
      c(
        "VOS",
        "NMVOS",
        "KWS alif.niet gehalogen.",
        "KWS niet-gehalogeneerd",
        "KWS2000, Totaal",
        "KWS arom.niet gehalogeneerd",
        "KWS arom.gehalogeneerd",
        "KWS alif.gehalogeneerd",
        "Halogeenverb.org.",
        "Chloorparaffines (C1-C3)",
        "CFK, H(C)FK en Halonen",
        "PAK (16 van EPA)",
        "PAK (10 van VROM)",
        "PAK (6 van Borneff)",
        "PAK (4 van PRTR)",
        "BTEX",
        "Chloorfluorkoolstoffen (CFK's)",
        "Chloorfluorkoolwaterstoffen",
        "HCFK's of H-Cl-F-KWS",
        "Chloorbenzenen",
        "Nonylfenol/Ethoxylaten(Np/Npe)",
        "Drins (Aldrin, Dieldrin)",
        "Cyaniden",
        "Thiocarbamaten",
        "Zwaveloxiden (als SO2)",
        "HFK's of H-F-KWS",
        "Organotinverbindingen",
        "Halonen",
        "Ftalaten",
        "Fenol en Fenolaten",
        "Chloorfenolen"
      )
  ) |>
  dplyr::distinct(
    aquo_code,
    aquo_naam,
    gepresenteerde_stof_code,
    gepresenteerde_stof_naam
  ) |>
  arrow::write_parquet(
    file.path(
      paths$external,
      paste0("rekenfactoren_er_cleaned_", settings$run_date, ".parquet")
    )
  )

# dubbele_naam <- test2 |>
#   dplyr::distinct(
#     gepresenteerde_stof_naam,
#     aquo_code,
#     aquo_naam
#   ) |>
#   dplyr::group_by(aquo_naam) |>
#   dplyr::filter(dplyr::n() > 1) |>
#   dplyr::ungroup() |>
#   dplyr::arrange(aquo_naam)
#er zijn nog gepresenteerde stoffen met en
