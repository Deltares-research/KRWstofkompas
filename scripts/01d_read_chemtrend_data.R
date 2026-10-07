chemtrend_meetdata <-
  arrow::read_parquet(
    file.path(
      "P:/sito-wbk-07/2026/012-Chemtrend/R/CHEMTrend/data/tussen/02_data_for_trend_analysis_vanaf_2009.parquet"
    )
  )

chemtrend_landelijk_lowess <-
  readr::read_csv(
    file.path(
      "P:/sito-wbk-07/2026/012-Chemtrend/R/CHEMTrend/data/bewerkt/04B_data_trend_ats_landelijk_vanaf_2009.csv"
    )
  )

chemtrend_stroomgebied_lowess <-
  readr::read_csv(
    file.path(
      "P:/sito-wbk-07/2026/012-Chemtrend/R/CHEMTrend/data/bewerkt/06B_data_trend_ats_stroomgebied_vanaf_2009.csv"
    )
  )

chemtrend_waterlichaam_lowess <-
  readr::read_csv(
    file.path(
      "P:/sito-wbk-07/2026/012-Chemtrend/R/CHEMTrend/data/bewerkt/05B_data_trend_ats_waterbeheerder_vanaf_2009.csv"
    )
  )
