# 3a) LOCATIEPLOT
plot_chemtrend_by_code <- function(
  locations_data,
  substance_code,
  location_code,
  trend_period = 0L
) {
  d <- locations_data |>
    filter(
      .data$substance_code == .env$substance_code,
      .data$location_code == .env$location_code,
      .data$trend_period == as.integer(.env$trend_period)
    )

  if (nrow(d) == 0) {
    stop("Geen data gevonden voor deze combinatie.")
  }

  d$date <- as.Date(d$x_value)

  ggplot(d, aes(x = date)) +
    geom_line(
      aes(y = y_value_meting, color = "Meting"),
      linewidth = 0.4,
      na.rm = TRUE
    ) +
    geom_line(
      aes(y = y_value_lowess, color = "Lowess"),
      linewidth = 0.8,
      na.rm = TRUE
    ) +
    geom_line(
      aes(y = y_value_theil_sen, color = "Theil Sen"),
      linetype = "dashed",
      linewidth = 0.7,
      na.rm = TRUE
    ) +
    scale_color_manual(
      values = c(
        "Meting" = "#9f4a96",
        "Lowess" = "#94cbec",
        "Theil Sen" = "#FFA500"
      )
    ) +
    labs(
      title = unique(d$title)[1],
      subtitle = paste(
        unique(d$subtitle_1)[1],
        unique(d$subtitle_2)[1],
        sep = "\n"
      ),
      x = NULL,
      y = paste0("[", unique(na.omit(d$unit))[1], "]"),
      color = NULL
    ) +
    theme_bw() +
    theme(legend.position = "bottom")
}

# 3b) REGIOPLOT (bijv. Nederland)
plot_chemtrend_region_by_code <- function(
  regions_data,
  substance_code,
  region_id,
  trend_period = 0L,
  show_locations = TRUE
) {
  d <- regions_data |>
    filter(
      .data$substance_code == .env$substance_code,
      .data$regio_id == as.integer(.env$region_id),
      .data$trend_period == as.integer(.env$trend_period)
    )

  if (nrow(d) == 0) {
    stop("Geen regiodata gevonden voor deze combinatie.")
  }

  d$date <- as.Date(d$x_value)
  d$value <- as.numeric(d$y_value_lowess)

  summaries <- d |> filter(.data$trend_label %in% c("p25", "p50", "p75"))
  locations <- d |> filter(!.data$trend_label %in% c("p25", "p50", "p75"))

  y_max <- max(
    c(
      if (show_locations && nrow(locations) > 0) summaries$value,
      summaries$value
    ),
    na.rm = TRUE
  )

  p <- ggplot()

  if (show_locations && nrow(locations) > 0) {
    p <- p +
      geom_line(
        data = locations,
        aes(
          x = date,
          y = value,
          group = trend_label,
          color = trend_direction,
          text = paste0(
            "Locatie: ",
            trend_label,
            "<br>Datum: ",
            date,
            "<br>Waarde: ",
            value,
            "<br>Trend: ",
            recode(
              trend_direction,
              downwards = "Dalende trend",
              inconclusive = "Geen significante trend",
              upwards = "Stijgende trend",
              p25 = "P25",
              p50 = "Mediaan",
              p75 = "P75"
            )
          )
        ),
        alpha = 0.35,
        linewidth = 0.4,
        show.legend = FALSE
      )
  }

  p <- p +
    geom_line(
      data = summaries,
      aes(
        x = date,
        y = value,
        group = trend_label,
        color = trend_label,
        linetype = trend_label,
        text = paste0(
          "Reeks: ",
          trend_label,
          "<br>Datum: ",
          date,
          "<br>Waarde: ",
          value
        )
      ),
      linewidth = 0.9
    ) +
    scale_color_manual(
      values = c(
        downwards = "#94cbec",
        inconclusive = "#E7DD87",
        upwards = "#d73027",
        p25 = "grey",
        p50 = "black",
        p75 = "grey"
      ),
      breaks = c(
        "downwards",
        "inconclusive",
        "upwards",
        "p25",
        "p50",
        "p75"
      ),
      labels = c(
        downwards = "Dalende trend",
        inconclusive = "Geen significante trend",
        upwards = "Stijgende trend",
        p25 = "P25",
        p50 = "Mediaan",
        p75 = "P75"
      )
    ) +
    scale_linetype_manual(
      values = c(
        p25 = "dashed",
        p50 = "solid",
        p75 = "dashed"
      ),
      breaks = c("p25", "p50", "p75"),
      labels = c(
        p25 = "P25",
        p50 = "Mediaan",
        p75 = "P75"
      )
    ) +
    coord_cartesian(ylim = c(0, y_max * 1.05)) +
    labs(
      title = unique(d$title)[1],
      x = NULL,
      y = paste0("[", unique(na.omit(d$unit))[1], "]"),
      color = NULL,
      linetype = NULL
    ) +
    theme_bw() +
    theme(legend.position = "bottom")
}
