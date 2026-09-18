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
