#load libraries
source(
  here(
    "scripts",
    "functies.R"
  )
)

# inladen chemtrend data
trend_info_landelijk <-
  readr::read_csv2(
    "P:/sito-wbk-07/2026/012-Chemtrend/R/CHEMTrend/data/bewerkt/trend_info_per_parameter.csv"
  )

trend_info_per_stroomgebied <-
  readr::read_csv2(
    "P:/sito-wbk-07/2026/012-Chemtrend/R/CHEMTrend/data/bewerkt/trend_info_per_stroomgebied.csv"
  )


trend_info_per_waterlichaam <-
  readr::read_csv2(
    "P:/sito-wbk-07/2026/012-Chemtrend/R/CHEMTrend/data/bewerkt/trend_info_per_waterlichaam.csv"
  )

trend_info_per_locatie <-
  readr::read_csv2(
    "P:/sito-wbk-07/2026/012-Chemtrend/R/CHEMTrend/data/bewerkt/trend_info_per_locatie.csv"
  )


# inladen GIS data
gis_stroomgebied <-
  sf::read_sf(
    here(
      "data",
      "1_raw",
      "gis",
      "deelstroomgebieden",
      "deelstroomgebied.shp"
    )
  )

gis_waterlichaam <-
  sf::read_sf(
    here(
      "data",
      "1_raw",
      "gis",
      "KRW-waterlichamen",
      "OWL_KRWNUTrend_2026_20260414 - Copy",
      "OWL_KRWNUTrend_2026_20260414 - Copy.shp"
    )
  )
