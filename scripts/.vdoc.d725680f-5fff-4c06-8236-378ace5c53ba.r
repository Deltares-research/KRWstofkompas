#
#
#| label: chemtrend inladen
#| echo: false
#| output: false
#| message: false
#| include: false
#laad libraries, paths en functies
source(here::here("scripts", "functies.R"))
source(here::here("scripts", "paths.R"))

#laad data 
#chemtrend data
bestand <- list.files(
  path = paths$external,
  pattern = "chemtrend_data_.*\\.qs2$",
  full.names = TRUE
) |>
  (\(x) x[which.max(file.info(x)$mtime)])()

chemtrend_data <- qs2::qs_read(bestand)
#
#
#
#
#
#| label: chemtrend samenvatten
#| echo: false
#| output: false
#| message: false
#| include: false

#om een stof te testen moeten we even een stof als voorbeeld nemen
stof <- "Cd"

overzicht_trend <- chemtrend_data |>
  filter(parameter_code == stof) |> 
  group_by(aggregatieniveau, parameter_code, parameter_naam) |>
  summarise(
    aantal = n(),
    aantal_dalend = sum(trend_conclusie == "neerwaarts significant", na.rm = TRUE),
    aantal_stijgend = sum(trend_conclusie == "opwaarts significant", na.rm = TRUE),
    aantal_geen = sum(trend_conclusie == "niet significant", na.rm = TRUE),
    .groups = "drop"
  ) |>
    mutate(
      percentage_stijgend = round(aantal_stijgend / aantal * 100, 1),
      percentage_dalend = round(aantal_dalend / aantal * 100, 1),
          ) 

richting_landelijk <- case_when(
  overzicht_trend$aantal_dalend[overzicht_trend$aggregatieniveau == "Landelijk"] == 1 ~ "neerwaarts",
  overzicht_trend$aantal_stijgend[overzicht_trend$aggregatieniveau == "Landelijk"] == 1 ~ "opwaarts",
  overzicht_trend$aantal_geen[overzicht_trend$aggregatieniveau == "Landelijk"] == 1 ~ "niet significante"
)

#
#
#
#
#
#
#
#
#
#
#
#| label: chemtrend-tabel-overzicht
#| echo: false
#| output: true
#| message: false
 knitr::kable(
  overzicht_trend |>
    mutate(
      opwaartse_trend = paste0(
        aantal_stijgend,
        " (", percentage_stijgend, "%)"
      ),
      neerwaartse_trend = paste0(
        aantal_dalend,
        " (", percentage_dalend, "%)"
      ),
      geen_significante_trend = paste0(
        aantal_geen,
        " (", round(aantal_geen / aantal * 100, 1), "%)"
      )
    ) |>
    select(
      aggregatieniveau,
      aantal,
      opwaartse_trend,
      neerwaartse_trend,
      geen_significante_trend
    ),
  col.names = c(
    "Schaalniveau",
    "Aantal",
    "Opwaartse trend",
    "Neerwaartse trend",
    "Geen significante trend"
  ),
  caption = paste("Trendoverzicht", stof)
)

#
#
#
#| label: fig-chemtrend-data
#| echo: false
#| message: false

stroomgebied <- chemtrend_data |>
  filter(aggregatieniveau == "Stroomgebied") |>
  select(
    regio_omschrijving,
    trend_kleur_code,
    geometry
  ) |>
  distinct() |>
  sf::st_as_sf()

waterlichaam <- chemtrend_data |>
  filter(aggregatieniveau == "Waterlichaam") |>
  select(
    regio_omschrijving,
    trend_kleur_code,
    geometry
  ) |>
  distinct() |>
  sf::st_as_sf()
#
#
#
#| label: fig-chemtrend-kaarten
#| fig-cap: "Trends voor {stof} op stroomgebied- en waterlichaamniveau."
#| fig-subcap:
#|   - "Stroomgebieden"
#|   - "Waterlichamen"
#| layout-ncol: 2
#| echo: false
#| message: false

ggplot() +
  geom_sf(
    data = stroomgebied,
    aes(fill = trend_kleur_code),
    colour = "white",
    linewidth = 0.2
  ) +
  scale_fill_manual(
    values = trend_kleur,
    drop = FALSE
  ) +
  labs(
    fill = "Trend"
  ) +
  theme_void()

ggplot() +
  geom_sf(
    data = waterlichaam,
    aes(
      fill = trend_kleur_code,
      colour = trend_kleur_code
    ),
    linewidth = 0.3
  ) +
  scale_fill_manual(
    values = trend_kleur,
    drop = FALSE,
    guide = "none"
  ) +
  scale_colour_manual(
    values = trend_kleur,
    drop = FALSE,
    guide = "none"
  ) +
  theme_void()
#
#
#
#| label: chemtrend-interactieve-kaart
#| echo: false
#| output: true
#| message: false


stroomgebied <- st_transform(stroomgebied, 4326)
waterlichaam <- st_transform(waterlichaam, 4326)

leaflet(
  options = leafletOptions(preferCanvas = TRUE)
) |>
  addProviderTiles(providers$CartoDB.Positron) |>

  # -----------------------------------
  # Stroomgebieden
  # -----------------------------------

  addPolygons(
    data = stroomgebied,
    group = "Stroomgebieden",

    fillColor = ~trend_kleur,
    color = "white",

    weight = 1,
    fillOpacity = 0.6,

    popup = ~glue::glue(
      "<b>Stroomgebied</b><br>",
      "{NAAM}",
      "<br><br>",
      "<b>Trend:</b> {trend_kleur_code}"
    )
  ) |>

  # -----------------------------------
  # Waterlichamen
  # -----------------------------------

  addPolygons(
    data = waterlichaam,
    group = "Waterlichamen",

    fillColor = ~trend_kleur,
    color = ~trend_kleur,

    weight = 1,
    fillOpacity = 0.8,

    popup = ~glue::glue(
      "<b>Waterlichaam</b><br>",
      "{regio_omschrijving}",
      "<br><br>",
      "<b>Trend:</b> {trend_kleur_code}",
      "<br>"    )
  ) |>

  # -----------------------------------
  # Legenda
  # -----------------------------------

  addLegend(
    position = "bottomright",
    colors = unname(trend_kleur),
    labels = names(trend_kleur),
    opacity = 1,
    title = "Trend"
  ) |>

  # -----------------------------------
  # Lagen
  # -----------------------------------

  addLayersControl(
    overlayGroups = c(
      "Stroomgebieden",
      "Waterlichamen",
      "Meetpunten"
    ),
    options = layersControlOptions(
      collapsed = FALSE
    )
  )
#
#
#
#
