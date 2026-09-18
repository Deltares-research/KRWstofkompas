#libraries
library(tidyverse)
library(sf)
library(glue)
library(patchwork)
library(here)
library(leaflet)
library(htmltools)


#hulpfunctie voor het maken van trendcodes voor uniforme kaart en trendconclusies
maak_trend_code_uniform <- function(x) {
  case_when(
    x %in%
      c(
        "opwaarts significant",
        "trend opwaarts"
      ) ~ "Stijgende trend",

    x %in%
      c(
        "neerwaarts significant",
        "trend neerwaarts"
      ) ~ "Dalende trend",

    x %in%
      c(
        "niet significant",
        "geen trend"
      ) ~ "Geen significante trend",

    TRUE ~ "Te weinig metingen voor een trend"
  )
}

trend_kleur <- c(
  "Stijgende trend" = "#d73027",
  "Dalende trend" = "#94cbec",
  "Geen significante trend" = "#E7DD87",
  "Te weinig metingen voor een trend" = "#dddddd"
)

trend_analyse_stof <- function(
  stof,
  trend_info_landelijk,
  trend_info_per_stroomgebied,
  trend_info_per_waterlichaam,
  trend_info_per_locatie
) {
  #----------------------------
  # Selecteer data
  #----------------------------

  landelijk <-
    trend_info_landelijk |>
    filter(parameter_code == stof)

  stroomgebied <-
    trend_info_per_stroomgebied |>
    filter(is.na(parameter_code) | parameter_code == stof) |>
    mutate(
      trend_kleur_code = maak_trend_code_uniform(trend_conclusie),
      trend_kleur_code = replace_na(
        trend_kleur_code,
        "Te weinig metingen voor een trend"
      )
    )

  waterlichaam <-
    trend_info_per_waterlichaam |>
    filter(
      is.na(parameter_code) | parameter_code == stof
    ) |>
    mutate(
      trend_kleur_code = maak_trend_code_uniform(trend_conclusie),
      trend_kleur_code = replace_na(
        trend_kleur_code,
        "Te weinig metingen voor een trend"
      )
    )

  meetpunt <-
    trend_info_per_locatie |>
    filter(parameter_code == stof) |>
    mutate(
      trend_kleur_code = maak_trend_code_uniform(skendall_trend)
    )

  #----------------------------
  # Landelijke richting
  #----------------------------

  richting <- case_when(
    landelijk$trend_conclusie == "neerwaarts significant" ~ "een **dalende**",
    landelijk$trend_conclusie == "opwaarts significant" ~ "een **stijgende**",
    TRUE ~ "geen significante"
  )

  #----------------------------
  # Overzichtstabel
  #----------------------------

  overzicht_landelijk <-
    landelijk |>
    group_by(parameter_code) |>
    summarise(
      aantal = n(),
      aantal_dalend = sum(trend_conclusie == "neerwaarts significant"),
      aantal_stijgend = sum(trend_conclusie == "opwaarts significant"),
      aantal_geen = sum(trend_conclusie == "niet significant"),
      .groups = "drop"
    ) |>
    mutate(aggregatie = "landelijk")

  overzicht_stroomgebied <-
    stroomgebied |>
    st_drop_geometry() |>
    group_by(parameter_code) |>
    summarise(
      aantal = n(),
      aantal_stijgend = sum(trend_conclusie == "opwaarts significant"),
      aantal_dalend = sum(trend_conclusie == "neerwaarts significant"),
      aantal_geen = sum(trend_conclusie == "niet significant"),
      .groups = "drop"
    ) |>
    mutate(
      percentage_stijgend = round(aantal_stijgend / aantal * 100, 1),
      aggregatie = "stroomgebied"
    ) |>
    relocate(
      percentage_stijgend,
      .after = aantal_stijgend
    )

  overzicht_waterlichaam <-
    waterlichaam |>
    st_drop_geometry() |>
    group_by(parameter_code) |>
    summarise(
      aantal = n(),
      aantal_stijgend = sum(trend_conclusie == "opwaarts significant"),
      aantal_dalend = sum(trend_conclusie == "neerwaarts significant"),
      aantal_geen = sum(trend_conclusie == "niet significant"),
      .groups = "drop"
    ) |>
    mutate(
      percentage_stijgend = round(aantal_stijgend / aantal * 100, 1),
      aggregatie = "waterlichaam"
    ) |>
    relocate(
      percentage_stijgend,
      .after = aantal_stijgend
    )

  overzicht_locaties <-
    meetpunt |>
    group_by(parameter_code) |>
    summarise(
      aantal = n(),
      aantal_stijgend = sum(skendall_trend == "trend opwaarts"),
      aantal_dalend = sum(skendall_trend == "trend neerwaarts"),
      aantal_geen = sum(skendall_trend == "geen trend"),
      .groups = "drop"
    ) |>
    mutate(
      percentage_stijgend = round(aantal_stijgend / aantal * 100, 1),
      aggregatie = "meetlocatie"
    ) |>
    relocate(
      percentage_stijgend,
      .after = aantal_stijgend
    )

  overzicht_trend <-
    bind_rows(
      overzicht_landelijk,
      overzicht_stroomgebied,
      overzicht_waterlichaam,
      overzicht_locaties
    ) |>
    filter(!is.na(parameter_code))

  #----------------------------
  # Resultaat teruggeven
  #----------------------------

  list(
    stof = stof,
    richting = richting,
    landelijk = landelijk,
    stroomgebied = stroomgebied,
    waterlichaam = waterlichaam,
    meetpunt = meetpunt,
    overzicht_trend = overzicht_trend
  )
}
