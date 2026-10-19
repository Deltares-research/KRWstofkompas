# overzicht van paths

project_root <- "P:/sito-wbk-07/2026/002-KRW strategie/data"

paths <- list(
  raw = file.path(project_root, "1_raw"),
  external = file.path(project_root, "2_external"),
  interim = file.path(project_root, "3_interim"),
  processed = file.path(project_root, "4_processed"),
  output = file.path(project_root, "5_output")
)

settings <- list(
  run_date = format(Sys.Date(), "%Y%m%d"),
  project_name = "KRWstofkompas"
)