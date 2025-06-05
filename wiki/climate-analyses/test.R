library(tidyverse)
library(here)
library(glue)
library(sf)
library(rajudas)
library(jsonlite)

d <- read_csv("~/LIXO/test.csv")


d %>%
  filter(
    lubridate::hour(time) >= 22 |
      lubridate::hour(time) < 6
  ) %>%
  summarise(m = mean(tl, na.rm = T))
