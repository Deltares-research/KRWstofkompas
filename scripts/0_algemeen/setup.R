# Gedeelde setup voor rapporten en scripts: packages, paden en hulpfuncties.
# Overige packages worden aangeroepen als pkg::functie().
suppressPackageStartupMessages({
  library(tidyverse)
  library(sf)
  library(leaflet)
  library(plotly)
  library(DT)
  library(knitr)
})

source(here::here("scripts", "0_algemeen", "paths.R"))
source(here::here("scripts", "0_algemeen", "functies.R"))
source(here::here("scripts", "0_algemeen", "rivm_stofgegevens.R"))
