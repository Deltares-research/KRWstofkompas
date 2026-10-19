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

source(here::here("R", "paths.R"))
source(here::here("R", "functies.R"))
source(here::here("R", "rivm_stofgegevens.R"))
