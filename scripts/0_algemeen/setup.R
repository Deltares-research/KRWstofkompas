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
source(here::here("scripts", "0_algemeen", "stofindicatoren.R"))
source(here::here("scripts", "0_algemeen", "prioritering.R"))
source(here::here("scripts", "0_algemeen", "stoffenboek.R"))
source(here::here("scripts", "0_algemeen", "get_chemtrend_data.R"))
source(here::here("scripts", "0_algemeen", "chemtrend_plots.R"))

# Lettertype van de figuren gelijk aan de rapporttekst (--dl-font in stofrapport.css)
rapport_font <- "Segoe UI"
theme_set(theme_gray(base_family = rapport_font))
# ragg kan systeemlettertypen gebruiken; het standaard png-device op Windows niet
knitr::opts_chunk$set(dev = "ragg_png")
