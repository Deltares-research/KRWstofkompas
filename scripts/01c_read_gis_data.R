# inladen GIS data
source(here::here("scripts", "paths.R"))

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
