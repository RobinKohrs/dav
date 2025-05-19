# this file is used to test the geosphere_get_data function
library(davR)

# get the data
data = geosphere_get_data(
    resource_id = "spartacus-v2-1d-1km",
    parameters = "t_2m",
    start = "2023-05-01",
    end = "2023-05-01"
)
