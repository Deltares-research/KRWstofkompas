# Required packages:
# install.packages(c("DBI", "arrow"))

library(DBI)
library(arrow)

# con is passed in from outside
export_all_chemtrend_parquet <- function(
  con,
  out_dir = "data/chemtrend_parquet_all"
) {
  if (!DBI::dbIsValid(con)) {
    stop("`con` is not a valid open DBI connection.")
  }

  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  exported_at <- Sys.time()

  substances <- DBI::dbGetQuery(
    con,
    "
    SELECT substance_id, substance_code, substance_description, cas
    FROM chemtrend.substance
    ORDER BY substance_id
  "
  )

  periods <- DBI::dbGetQuery(
    con,
    "
    SELECT id, name, start
    FROM chemtrend.trend_period
    ORDER BY id
  "
  )

  region_lookup <- DBI::dbGetQuery(
    con,
    "
    SELECT region_id, region_type, region_description
    FROM chemtrend.region
    ORDER BY region_type, region_description
  "
  )

  locations_all <- DBI::dbGetQuery(
    con,
    "
  SELECT source.location_code,
         source.substance_id,
         s.substance_code,
         source.trend_period,
         source.title,
         source.subtitle_1,
         source.subtitle_2,
         source.unit,
         source.trend_direction,
         source.x_value,
         source.y_value_meting,
         source.y_value_lowess,
         source.y_value_theil_sen,
         source.point_filled
  FROM (
    SELECT * FROM chemtrend.trend
    UNION ALL
    SELECT * FROM chemtrend.measurement
  ) AS source
  LEFT JOIN chemtrend.substance AS s
    ON s.substance_id = source.substance_id
  ORDER BY source.substance_id,
           source.trend_period,
           source.location_code,
           source.x_value
  "
  )

  regions_all <- DBI::dbGetQuery(
    con,
    "
  SELECT source.regio_id,
         source.substance_id,
         s.substance_code,
         source.trend_period,
         source.title,
         source.region_type,
         source.unit,
         source.trend_label,
         source.trend_direction,
         source.x_value,
         source.y_value_lowess
  FROM chemtrend.trend_region AS source
  LEFT JOIN chemtrend.substance AS s
    ON s.substance_id = source.substance_id
  ORDER BY source.substance_id,
           source.trend_period,
           source.regio_id,
           source.trend_label,
           source.x_value
  "
  )

  # Aparte tabel met alle locaties die Chemtrend gebruikt.
  location_points <- DBI::dbGetQuery(
    con,
    "
  SELECT meetpunt_id,
         location_code,
         omschrijving,
         waterbeheerder,
         ST_X(geom) AS x,
         ST_Y(geom) AS y
  FROM chemtrend.location
  ORDER BY location_code
  "
  )

  metadata <- data.frame(
    exported_at = format(exported_at, tz = "UTC", usetz = TRUE),
    n_substances = nrow(substances),
    n_periods = nrow(periods),
    n_locations_rows = nrow(locations_all),
    n_regions_rows = nrow(regions_all),
    stringsAsFactors = FALSE
  )

  arrow::write_parquet(
    substances,
    file.path(out_dir, "substances.parquet"),
    compression = "snappy"
  )
  arrow::write_parquet(
    periods,
    file.path(out_dir, "periods.parquet"),
    compression = "snappy"
  )
  arrow::write_parquet(
    region_lookup,
    file.path(out_dir, "region_lookup.parquet"),
    compression = "snappy"
  )
  arrow::write_parquet(
    locations_all,
    file.path(out_dir, "locations_all.parquet"),
    compression = "snappy"
  )
  arrow::write_parquet(
    regions_all,
    file.path(out_dir, "regions_all.parquet"),
    compression = "snappy"
  )
  arrow::write_parquet(
    location_points,
    file.path(out_dir, "location_points.parquet"),
    compression = "snappy"
  )
  arrow::write_parquet(
    metadata,
    file.path(out_dir, "metadata.parquet"),
    compression = "snappy"
  )

  message("Export complete: ", out_dir)
  invisible(out_dir)
}

load_all_chemtrend_parquet <- function(out_dir = "data/chemtrend_parquet_all") {
  list(
    substances = read_parquet(file.path(out_dir, "substances.parquet")),
    periods = read_parquet(file.path(out_dir, "periods.parquet")),
    region_lookup = read_parquet(file.path(out_dir, "region_lookup.parquet")),
    locations_all = read_parquet(file.path(out_dir, "locations_all.parquet")),
    regions_all = read_parquet(file.path(out_dir, "regions_all.parquet")),
    location_points = read_parquet(file.path(
      out_dir,
      "location_points.parquet"
    )),
    metadata = read_parquet(file.path(out_dir, "metadata.parquet"))
  )
}

# install.packages("arrow")
library(arrow)

open_chemtrend_dataset <- function(out_dir = "data/chemtrend_parquet_all") {
  list(
    locations = open_dataset(
      file.path(out_dir, "locations_all.parquet"),
      format = "parquet"
    ),
    regions = open_dataset(
      file.path(out_dir, "regions_all.parquet"),
      format = "parquet"
    ),
    substances = read_parquet(file.path(out_dir, "substances.parquet")),
    periods = read_parquet(file.path(out_dir, "periods.parquet")),
    region_lookup = read_parquet(file.path(out_dir, "region_lookup.parquet")),
    location_points = read_parquet(file.path(
      out_dir,
      "location_points.parquet"
    )),
    metadata = read_parquet(file.path(out_dir, "metadata.parquet"))
  )
}

# Fast filter for one substance (+ optional period)
get_substance_data_by_code <- function(
  ds,
  substance_code,
  trend_period = NULL
) {
  if (
    !is.character(substance_code) ||
      length(substance_code) != 1L ||
      is.na(substance_code) ||
      !nzchar(trimws(substance_code))
  ) {
    stop("Geef één niet-lege substance_code op.")
  }

  code <- trimws(substance_code)

  loc_q <- ds$locations |>
    dplyr::filter(.data$substance_code == .env$code)

  reg_q <- ds$regions |>
    dplyr::filter(.data$substance_code == .env$code)

  if (!is.null(trend_period)) {
    if (
      length(trend_period) != 1L ||
        is.na(trend_period) ||
        !trend_period %in% c(0L, 1L)
    ) {
      stop("trend_period moet NULL, 0 of 1 zijn.")
    }

    tp <- as.integer(trend_period)

    loc_q <- loc_q |>
      dplyr::filter(.data$trend_period == .env$tp)

    reg_q <- reg_q |>
      dplyr::filter(.data$trend_period == .env$tp)
  }

  list(
    substance = ds$substances |>
      dplyr::filter(.data$substance_code == .env$code),
    locations = dplyr::collect(loc_q),
    regions = dplyr::collect(reg_q)
  )
}
