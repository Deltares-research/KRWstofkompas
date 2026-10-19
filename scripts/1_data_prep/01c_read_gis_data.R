# inladen GIS data
if (!exists("paths")) {
  source(here::here("scripts", "0_algemeen", "setup.R"))
}

gis_stroomgebied <-
  sf::read_sf(
    file.path(
      paths$raw,
      "gis",
      "deelstroomgebieden",
      "deelstroomgebied.shp"
    )
  )

gis_waterlichaam <-
  sf::read_sf(
    file.path(
      paths$raw,
      "gis",
      "KRW-waterlichamen",
      "OWL_KRWNUTrend_2026_20260414 - Copy",
      "OWL_KRWNUTrend_2026_20260414 - Copy.shp"
    )
  )

# Vereenvoudigen, want de volledige geometrie (6,3 mln punten) laat pandoc vastlopen
vereenvoudig <- function(x) {
  # Terugcasten: gemengde POLYGON/MULTIPOLYGON breekt de leaflet-kaart in 04
  sf::st_simplify(x, dTolerance = 25, preserveTopology = TRUE) |>
    sf::st_cast("MULTIPOLYGON")
}

saveRDS(
  vereenvoudig(gis_stroomgebied),
  file.path(
    paths$interim,
    paste0("gis_stroomgebied_", settings$run_date, ".rds")
  )
)
saveRDS(
  vereenvoudig(gis_waterlichaam),
  file.path(
    paths$interim,
    paste0("gis_waterlichaam_", settings$run_date, ".rds")
  )
)
