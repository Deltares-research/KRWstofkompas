meetdata_voor_chemtrend <-
  arrow::read_parquet(
    file.path(
      "P:/sito-wbk-07/2026/012-Chemtrend/R/CHEMTrend/data/tussen/02_data_for_trend_analysis_vanaf_2009.parquet"
    )
  )
