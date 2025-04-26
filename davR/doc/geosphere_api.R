## ---- include = FALSE---------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

## ----setup--------------------------------------------------------------------
library(davR)
library(DT)
library(readr)
library(dplyr)

## -----------------------------------------------------------------------------
ds = geosphere_get_datasets()
DT::datatable(ds)

