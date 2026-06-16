# Fetches the complete list of known individuals killed in Gaza

This function retrieves the dataset of names of those killed in Gaza.
The recommended method is using the default `format = "df"`, which
fetches the data page by page to avoid long request times and potential
timeouts with the full file.

## Usage

``` r
gaza_killed(format = "df", page = NULL, minified = TRUE, progress = TRUE)
```

## Arguments

- format:

  A string specifying the format.

  - "df" (default): Fetches all pages sequentially and combines them
    into a single data frame. Most robust method.

  - "csv": Downloads the complete dataset as a single CSV file and
    returns a data frame.

  - "json": Downloads the complete dataset as a single minified JSON
    file.

  - "page": Returns a specific page number (requires page parameter).

- page:

  Integer. Page number (1-602). Only used when format = "page".

- minified:

  Logical. Whether to return minified JSON. Default is TRUE.

- progress:

  Logical. Whether to show progress bar for multi-page downloads.
  Default is TRUE.

## Value

A data frame containing the list of names and associated details, or raw
JSON content.

## Details

**Data Source and Updates:** The file is updated when a new list is
released by Gaza's Ministry of Health.

This list incorporates the following releases from the Ministry of
Health:

- **First release** (January 5th, 2024): Hospitals reporting in the
  South and November 2nd 2023 for the North. Additionally, 21 records
  were included from an earlier release as noted in the February update.

- **Second release** (March 29th, 2024): Included submissions from the
  public to the Ministry (i.e., families of those killed). Changes
  detailed in April 29th update.

- **Third release** (April 30th, 2024): Released on May 5th from the
  Ministry. Changes detailed in June 26th update.

- **Fourth release** (June 30th, 2024): Released on July 24th from the
  Ministry. Changes detailed in September 7th update.

- **Fifth release** (August 31st, 2024): Released around September 15th
  by the Ministry. Changes detailed in September 21st update.

- **Sixth release** (March 23rd, 2025): Released on the same day by the
  Ministry via Iraq Body Count. Changes detailed in May 11th update.

- **Seventh release** (June 15th, 2025): Released on June 23rd from the
  Ministry via Iraq Body Count. Changes detailed in July 6th update.

- **Eighth release** (July 15th, 2025): Released on July 16th from the
  Ministry via Iraq Body Count. Changes detailed in July 20th update.

- **Ninth release** (July 31st, 2025): Released on August 4th from the
  Ministry via Iraq Body Count. Changes detailed in August 17th update.

**Data Limitations:** In their initial January 2024 update, the Ministry
indicated the following about the list:

- The missing persons and the bodies of those trapped under the rubble
  were not counted

- The unidentified people who arrived at hospitals were not counted

- The unidentified persons whose bodies were handed over by the
  occupation were not counted

- Those who were buried by their families without passing through
  hospitals were not counted

- The victims in Gaza and North Gaza were not counted after the date of
  stopping the information system in November

The aggregate numbers in the Daily Casualties - Gaza dataset will
necessarily diverge from this list due to the number of unidentified
people.

**Data Fields:** Each record contains:

- `name`: Original Arabic name from the source list

- `en_name`: English name translation

- `id`: Unique string identifier (format may change)

- `dob`: Date of birth in YYYY-MM-DD format, or empty string if not
  available

- `sex`: "m" for male or "f" for female

- `age`: Age as a number

- `source`: Source indicator - "h" (Ministry of Health), "c" (Public
  Submission), "j" (judicial or house committee), "u" (unknown)

## Examples

``` r
# Get the data as a data frame by fetching all pages (recommended)
killed_df = gaza_killed()
#> Fetching summary data from: https://data.techforpalestine.org/api/v3/summary.min.json
#> Fetching 602 pages of data. This may take a moment...
#>   |                                                                              |                                                                      |   0%  |                                                                              |                                                                      |   1%
#> Warning: Failed to fetch page 5 - Status code: 429
#>   |                                                                              |=                                                                     |   1%
#> Warning: Failed to fetch page 6 - Status code: 429
#> Warning: Failed to fetch page 7 - Status code: 429
#> Warning: Failed to fetch page 8 - Status code: 429
#> Warning: Failed to fetch page 9 - Status code: 429
#> Warning: Failed to fetch page 10 - Status code: 429
#>   |                                                                              |=                                                                     |   2%
#> Warning: Failed to fetch page 11 - Status code: 429
#> Warning: Failed to fetch page 12 - Status code: 429
#> Warning: Failed to fetch page 13 - Status code: 429
#>   |                                                                              |==                                                                    |   2%
#> Warning: Failed to fetch page 14 - Status code: 429
#> Warning: Failed to fetch page 15 - Status code: 429
#> Warning: Failed to fetch page 16 - Status code: 429
#>   |                                                                              |==                                                                    |   3%
#> Warning: Failed to fetch page 17 - Status code: 429
#> Warning: Failed to fetch page 18 - Status code: 429
#> Warning: Failed to fetch page 19 - Status code: 429
#> Warning: Failed to fetch page 20 - Status code: 429
#> Warning: Failed to fetch page 21 - Status code: 429
#> Warning: Failed to fetch page 22 - Status code: 429
#>   |                                                                              |===                                                                   |   4%
#> Warning: Failed to fetch page 23 - Status code: 429
#> Warning: Failed to fetch page 24 - Status code: 429
#> Warning: Failed to fetch page 25 - Status code: 429
#> Warning: Failed to fetch page 26 - Status code: 429
#> Warning: Failed to fetch page 27 - Status code: 429
#> Warning: Failed to fetch page 28 - Status code: 429
#>   |                                                                              |===                                                                   |   5%
#> Warning: Failed to fetch page 29 - Status code: 429
#> Warning: Failed to fetch page 30 - Status code: 429
#> Warning: Failed to fetch page 31 - Status code: 429
#>   |                                                                              |====                                                                  |   5%
#> Warning: Failed to fetch page 32 - Status code: 429
#> Warning: Failed to fetch page 33 - Status code: 429
#> Warning: Failed to fetch page 34 - Status code: 429
#>   |                                                                              |====                                                                  |   6%
#> Warning: Failed to fetch page 35 - Status code: 429
#> Warning: Failed to fetch page 36 - Status code: 429
#> Warning: Failed to fetch page 37 - Status code: 429
#> Warning: Failed to fetch page 38 - Status code: 429
#> Warning: Failed to fetch page 39 - Status code: 429
#>   |                                                                              |=====                                                                 |   6%
#> Warning: Failed to fetch page 40 - Status code: 429
#>   |                                                                              |=====                                                                 |   7%
#> Warning: Failed to fetch page 41 - Status code: 429
#> Warning: Failed to fetch page 42 - Status code: 429
#> Warning: Failed to fetch page 43 - Status code: 429
#> Warning: Failed to fetch page 44 - Status code: 429
#> Warning: Failed to fetch page 45 - Status code: 429
#> Warning: Failed to fetch page 46 - Status code: 429
#>   |                                                                              |=====                                                                 |   8%
#> Warning: Failed to fetch page 47 - Status code: 429
#> Warning: Failed to fetch page 48 - Status code: 429
#>   |                                                                              |======                                                                |   8%
#> Warning: Failed to fetch page 49 - Status code: 429
#> Warning: Failed to fetch page 50 - Status code: 429
#> Warning: Failed to fetch page 51 - Status code: 429
#> Warning: Failed to fetch page 52 - Status code: 429
#>   |                                                                              |======                                                                |   9%
#> Warning: Failed to fetch page 53 - Status code: 429
#> Warning: Failed to fetch page 54 - Status code: 429
#> Warning: Failed to fetch page 55 - Status code: 429
#> Warning: Failed to fetch page 56 - Status code: 429
#>   |                                                                              |=======                                                               |   9%
#> Warning: Failed to fetch page 57 - Status code: 429
#> Warning: Failed to fetch page 58 - Status code: 429
#>   |                                                                              |=======                                                               |  10%
#> Warning: Failed to fetch page 59 - Status code: 429
#> Warning: Failed to fetch page 60 - Status code: 429
#> Warning: Failed to fetch page 61 - Status code: 429
#> Warning: Failed to fetch page 62 - Status code: 429
#> Warning: Failed to fetch page 63 - Status code: 429
#> Warning: Failed to fetch page 64 - Status code: 429
#>   |                                                                              |=======                                                               |  11%
#> Warning: Failed to fetch page 65 - Status code: 429
#>   |                                                                              |========                                                              |  11%
#> Warning: Failed to fetch page 66 - Status code: 429
#> Warning: Failed to fetch page 67 - Status code: 429
#> Warning: Failed to fetch page 68 - Status code: 429
#> Warning: Failed to fetch page 69 - Status code: 429
#> Warning: Failed to fetch page 70 - Status code: 429
#>   |                                                                              |========                                                              |  12%
#> Warning: Failed to fetch page 71 - Status code: 429
#> Warning: Failed to fetch page 72 - Status code: 429
#> Warning: Failed to fetch page 73 - Status code: 429
#> Warning: Failed to fetch page 74 - Status code: 429
#>   |                                                                              |=========                                                             |  12%
#> Warning: Failed to fetch page 75 - Status code: 429
#> Warning: Failed to fetch page 76 - Status code: 429
#>   |                                                                              |=========                                                             |  13%
#> Warning: Failed to fetch page 77 - Status code: 429
#> Warning: Failed to fetch page 78 - Status code: 429
#> Warning: Failed to fetch page 79 - Status code: 429
#> Warning: Failed to fetch page 80 - Status code: 429
#> Warning: Failed to fetch page 81 - Status code: 429
#> Warning: Failed to fetch page 82 - Status code: 429
#>   |                                                                              |==========                                                            |  14%
#> Warning: Failed to fetch page 83 - Status code: 429
#> Warning: Failed to fetch page 84 - Status code: 429
#> Warning: Failed to fetch page 85 - Status code: 429
#> Warning: Failed to fetch page 86 - Status code: 429
#> Warning: Failed to fetch page 87 - Status code: 429
#> Warning: Failed to fetch page 88 - Status code: 429
#>   |                                                                              |==========                                                            |  15%
#> Warning: Failed to fetch page 89 - Status code: 429
#> Warning: Failed to fetch page 90 - Status code: 429
#> Warning: Failed to fetch page 91 - Status code: 429
#>   |                                                                              |===========                                                           |  15%
#> Warning: Failed to fetch page 92 - Status code: 429
#> Warning: Failed to fetch page 93 - Status code: 429
#> Warning: Failed to fetch page 94 - Status code: 429
#>   |                                                                              |===========                                                           |  16%
#> Warning: Failed to fetch page 95 - Status code: 429
#> Warning: Failed to fetch page 96 - Status code: 429
#> Warning: Failed to fetch page 97 - Status code: 429
#> Warning: Failed to fetch page 98 - Status code: 429
#> Warning: Failed to fetch page 99 - Status code: 429
#>   |                                                                              |============                                                          |  16%
#> Warning: Failed to fetch page 100 - Status code: 429
#>   |                                                                              |============                                                          |  17%
#> Warning: Failed to fetch page 101 - Status code: 429
#> Warning: Failed to fetch page 102 - Status code: 429
#> Warning: Failed to fetch page 103 - Status code: 429
#> Warning: Failed to fetch page 104 - Status code: 429
#> Warning: Failed to fetch page 105 - Status code: 429
#> Warning: Failed to fetch page 106 - Status code: 429
#>   |                                                                              |============                                                          |  18%
#> Warning: Failed to fetch page 107 - Status code: 429
#> Warning: Failed to fetch page 108 - Status code: 429
#>   |                                                                              |=============                                                         |  18%
#> Warning: Failed to fetch page 109 - Status code: 429
#> Warning: Failed to fetch page 110 - Status code: 429
#> Warning: Failed to fetch page 111 - Status code: 429
#> Warning: Failed to fetch page 112 - Status code: 429
#>   |                                                                              |=============                                                         |  19%
#> Warning: Failed to fetch page 113 - Status code: 429
#> Warning: Failed to fetch page 114 - Status code: 429
#> Warning: Failed to fetch page 115 - Status code: 429
#> Warning: Failed to fetch page 116 - Status code: 429
#> Warning: Failed to fetch page 117 - Status code: 429
#>   |                                                                              |==============                                                        |  19%
#> Warning: Failed to fetch page 118 - Status code: 429
#>   |                                                                              |==============                                                        |  20%
#> Warning: Failed to fetch page 119 - Status code: 429
#> Warning: Failed to fetch page 120 - Status code: 429
#> Warning: Failed to fetch page 121 - Status code: 429
#> Warning: Failed to fetch page 122 - Status code: 429
#> Warning: Failed to fetch page 123 - Status code: 429
#> Warning: Failed to fetch page 124 - Status code: 429
#>   |                                                                              |==============                                                        |  21%
#> Warning: Failed to fetch page 125 - Status code: 429
#>   |                                                                              |===============                                                       |  21%
#> Warning: Failed to fetch page 126 - Status code: 429
#> Warning: Failed to fetch page 127 - Status code: 429
#> Warning: Failed to fetch page 128 - Status code: 429
#> Warning: Failed to fetch page 129 - Status code: 429
#> Warning: Failed to fetch page 130 - Status code: 429
#>   |                                                                              |===============                                                       |  22%
#> Warning: Failed to fetch page 131 - Status code: 429
#> Warning: Failed to fetch page 132 - Status code: 429
#> Warning: Failed to fetch page 133 - Status code: 429
#> Warning: Failed to fetch page 134 - Status code: 429
#>   |                                                                              |================                                                      |  22%
#> Warning: Failed to fetch page 135 - Status code: 429
#> Warning: Failed to fetch page 136 - Status code: 429
#>   |                                                                              |================                                                      |  23%
#> Warning: Failed to fetch page 137 - Status code: 429
#> Warning: Failed to fetch page 138 - Status code: 429
#> Warning: Failed to fetch page 139 - Status code: 429
#> Warning: Failed to fetch page 140 - Status code: 429
#> Warning: Failed to fetch page 141 - Status code: 429
#> Warning: Failed to fetch page 142 - Status code: 429
#>   |                                                                              |=================                                                     |  24%
#> Warning: Failed to fetch page 143 - Status code: 429
#> Warning: Failed to fetch page 144 - Status code: 429
#> Warning: Failed to fetch page 145 - Status code: 429
#> Warning: Failed to fetch page 146 - Status code: 429
#> Warning: Failed to fetch page 147 - Status code: 429
#> Warning: Failed to fetch page 148 - Status code: 429
#>   |                                                                              |=================                                                     |  25%
#> Warning: Failed to fetch page 149 - Status code: 429
#> Warning: Failed to fetch page 150 - Status code: 429
#> Warning: Failed to fetch page 151 - Status code: 429
#>   |                                                                              |==================                                                    |  25%
#> Warning: Failed to fetch page 152 - Status code: 429
#> Warning: Failed to fetch page 153 - Status code: 429
#> Warning: Failed to fetch page 154 - Status code: 429
#>   |                                                                              |==================                                                    |  26%
#> Warning: Failed to fetch page 155 - Status code: 429
#> Warning: Failed to fetch page 156 - Status code: 429
#> Warning: Failed to fetch page 157 - Status code: 429
#> Warning: Failed to fetch page 158 - Status code: 429
#> Warning: Failed to fetch page 159 - Status code: 429
#> Warning: Failed to fetch page 160 - Status code: 429
#>   |                                                                              |===================                                                   |  27%
#> Warning: Failed to fetch page 161 - Status code: 429
#> Warning: Failed to fetch page 162 - Status code: 429
#> Warning: Failed to fetch page 163 - Status code: 429
#> Warning: Failed to fetch page 164 - Status code: 429
#> Warning: Failed to fetch page 165 - Status code: 429
#> Warning: Failed to fetch page 166 - Status code: 429
#>   |                                                                              |===================                                                   |  28%
#> Warning: Failed to fetch page 167 - Status code: 429
#> Warning: Failed to fetch page 168 - Status code: 429
#>   |                                                                              |====================                                                  |  28%
#> Warning: Failed to fetch page 169 - Status code: 429
#> Warning: Failed to fetch page 170 - Status code: 429
#> Warning: Failed to fetch page 171 - Status code: 429
#> Warning: Failed to fetch page 172 - Status code: 429
#>   |                                                                              |====================                                                  |  29%
#> Warning: Failed to fetch page 173 - Status code: 429
#> Warning: Failed to fetch page 174 - Status code: 429
#> Warning: Failed to fetch page 175 - Status code: 429
#> Warning: Failed to fetch page 176 - Status code: 429
#> Warning: Failed to fetch page 177 - Status code: 429
#>   |                                                                              |=====================                                                 |  29%
#> Warning: Failed to fetch page 178 - Status code: 429
#>   |                                                                              |=====================                                                 |  30%
#> Warning: Failed to fetch page 179 - Status code: 429
#> Warning: Failed to fetch page 180 - Status code: 429
#> Warning: Failed to fetch page 181 - Status code: 429
#> Warning: Failed to fetch page 182 - Status code: 429
#> Warning: Failed to fetch page 183 - Status code: 429
#> Warning: Failed to fetch page 184 - Status code: 429
#>   |                                                                              |=====================                                                 |  31%
#> Warning: Failed to fetch page 185 - Status code: 429
#>   |                                                                              |======================                                                |  31%
#> Warning: Failed to fetch page 186 - Status code: 429
#> Warning: Failed to fetch page 187 - Status code: 429
#> Warning: Failed to fetch page 188 - Status code: 429
#> Warning: Failed to fetch page 189 - Status code: 429
#> Warning: Failed to fetch page 190 - Status code: 429
#>   |                                                                              |======================                                                |  32%
#> Warning: Failed to fetch page 191 - Status code: 429
#> Warning: Failed to fetch page 192 - Status code: 429
#> Warning: Failed to fetch page 193 - Status code: 429
#> Warning: Failed to fetch page 194 - Status code: 429
#>   |                                                                              |=======================                                               |  32%
#> Warning: Failed to fetch page 195 - Status code: 429
#> Warning: Failed to fetch page 196 - Status code: 429
#>   |                                                                              |=======================                                               |  33%
#> Warning: Failed to fetch page 197 - Status code: 429
#> Warning: Failed to fetch page 198 - Status code: 429
#> Warning: Failed to fetch page 199 - Status code: 429
#> Warning: Failed to fetch page 200 - Status code: 429
#> Warning: Failed to fetch page 201 - Status code: 429
#> Warning: Failed to fetch page 202 - Status code: 429
#>   |                                                                              |=======================                                               |  34%
#> Warning: Failed to fetch page 203 - Status code: 429
#>   |                                                                              |========================                                              |  34%
#> Warning: Failed to fetch page 204 - Status code: 429
#> Warning: Failed to fetch page 205 - Status code: 429
#> Warning: Failed to fetch page 206 - Status code: 429
#> Warning: Failed to fetch page 207 - Status code: 429
#> Warning: Failed to fetch page 208 - Status code: 429
#>   |                                                                              |========================                                              |  35%
#> Warning: Failed to fetch page 209 - Status code: 429
#> Warning: Failed to fetch page 210 - Status code: 429
#> Warning: Failed to fetch page 211 - Status code: 429
#>   |                                                                              |=========================                                             |  35%
#> Warning: Failed to fetch page 212 - Status code: 429
#> Warning: Failed to fetch page 213 - Status code: 429
#> Warning: Failed to fetch page 214 - Status code: 429
#>   |                                                                              |=========================                                             |  36%
#> Warning: Failed to fetch page 215 - Status code: 429
#> Warning: Failed to fetch page 216 - Status code: 429
#> Warning: Failed to fetch page 217 - Status code: 429
#> Warning: Failed to fetch page 218 - Status code: 429
#> Warning: Failed to fetch page 219 - Status code: 429
#> Warning: Failed to fetch page 220 - Status code: 429
#>   |                                                                              |==========================                                            |  37%
#> Warning: Failed to fetch page 221 - Status code: 429
#> Warning: Failed to fetch page 222 - Status code: 429
#> Warning: Failed to fetch page 223 - Status code: 429
#> Warning: Failed to fetch page 224 - Status code: 429
#> Warning: Failed to fetch page 225 - Status code: 429
#> Warning: Failed to fetch page 226 - Status code: 429
#>   |                                                                              |==========================                                            |  38%
#> Warning: Failed to fetch page 227 - Status code: 429
#> Warning: Failed to fetch page 228 - Status code: 429
#>   |                                                                              |===========================                                           |  38%
#> Warning: Failed to fetch page 229 - Status code: 429
#> Warning: Failed to fetch page 230 - Status code: 429
#> Warning: Failed to fetch page 231 - Status code: 429
#> Warning: Failed to fetch page 232 - Status code: 429
#>   |                                                                              |===========================                                           |  39%
#> Warning: Failed to fetch page 233 - Status code: 429
#> Warning: Failed to fetch page 234 - Status code: 429
#> Warning: Failed to fetch page 235 - Status code: 429
#> Warning: Failed to fetch page 236 - Status code: 429
#> Warning: Failed to fetch page 237 - Status code: 429
#>   |                                                                              |============================                                          |  39%
#> Warning: Failed to fetch page 238 - Status code: 429
#>   |                                                                              |============================                                          |  40%
#> Warning: Failed to fetch page 239 - Status code: 429
#> Warning: Failed to fetch page 240 - Status code: 429
#> Warning: Failed to fetch page 241 - Status code: 429
#> Warning: Failed to fetch page 242 - Status code: 429
#> Warning: Failed to fetch page 243 - Status code: 429
#> Warning: Failed to fetch page 244 - Status code: 429
#>   |                                                                              |============================                                          |  41%
#> Warning: Failed to fetch page 245 - Status code: 429
#> Warning: Failed to fetch page 246 - Status code: 429
#>   |                                                                              |=============================                                         |  41%
#> Warning: Failed to fetch page 247 - Status code: 429
#> Warning: Failed to fetch page 248 - Status code: 429
#> Warning: Failed to fetch page 249 - Status code: 429
#> Warning: Failed to fetch page 250 - Status code: 429
#>   |                                                                              |=============================                                         |  42%
#> Warning: Failed to fetch page 251 - Status code: 429
#> Warning: Failed to fetch page 252 - Status code: 429
#> Warning: Failed to fetch page 253 - Status code: 429
#> Warning: Failed to fetch page 254 - Status code: 429
#>   |                                                                              |==============================                                        |  42%
#> Warning: Failed to fetch page 255 - Status code: 429
#> Warning: Failed to fetch page 256 - Status code: 429
#>   |                                                                              |==============================                                        |  43%
#> Warning: Failed to fetch page 257 - Status code: 429
#> Warning: Failed to fetch page 258 - Status code: 429
#> Warning: Failed to fetch page 259 - Status code: 429
#> Warning: Failed to fetch page 260 - Status code: 429
#> Warning: Failed to fetch page 261 - Status code: 429
#> Warning: Failed to fetch page 262 - Status code: 429
#>   |                                                                              |==============================                                        |  44%
#> Warning: Failed to fetch page 263 - Status code: 429
#>   |                                                                              |===============================                                       |  44%
#> Warning: Failed to fetch page 264 - Status code: 429
#> Warning: Failed to fetch page 265 - Status code: 429
#> Warning: Failed to fetch page 266 - Status code: 429
#> Warning: Failed to fetch page 267 - Status code: 429
#> Warning: Failed to fetch page 268 - Status code: 429
#>   |                                                                              |===============================                                       |  45%
#> Warning: Failed to fetch page 269 - Status code: 429
#> Warning: Failed to fetch page 270 - Status code: 429
#> Warning: Failed to fetch page 271 - Status code: 429
#>   |                                                                              |================================                                      |  45%
#> Warning: Failed to fetch page 272 - Status code: 429
#> Warning: Failed to fetch page 273 - Status code: 429
#> Warning: Failed to fetch page 274 - Status code: 429
#>   |                                                                              |================================                                      |  46%
#> Warning: Failed to fetch page 275 - Status code: 429
#> Warning: Failed to fetch page 276 - Status code: 429
#> Warning: Failed to fetch page 277 - Status code: 429
#> Warning: Failed to fetch page 278 - Status code: 429
#> Warning: Failed to fetch page 279 - Status code: 429
#> Warning: Failed to fetch page 280 - Status code: 429
#>   |                                                                              |=================================                                     |  47%
#> Warning: Failed to fetch page 281 - Status code: 429
#> Warning: Failed to fetch page 282 - Status code: 429
#> Warning: Failed to fetch page 283 - Status code: 429
#> Warning: Failed to fetch page 284 - Status code: 429
#> Warning: Failed to fetch page 285 - Status code: 429
#> Warning: Failed to fetch page 286 - Status code: 429
#>   |                                                                              |=================================                                     |  48%
#> Warning: Failed to fetch page 287 - Status code: 429
#> Warning: Failed to fetch page 288 - Status code: 429
#> Warning: Failed to fetch page 289 - Status code: 429
#>   |                                                                              |==================================                                    |  48%
#> Warning: Failed to fetch page 290 - Status code: 429
#> Warning: Failed to fetch page 291 - Status code: 429
#> Warning: Failed to fetch page 292 - Status code: 429
#>   |                                                                              |==================================                                    |  49%
#> Warning: Failed to fetch page 293 - Status code: 429
#> Warning: Failed to fetch page 294 - Status code: 429
#> Warning: Failed to fetch page 295 - Status code: 429
#> Warning: Failed to fetch page 296 - Status code: 429
#> Warning: Failed to fetch page 297 - Status code: 429
#>   |                                                                              |===================================                                   |  49%
#> Warning: Failed to fetch page 298 - Status code: 429
#>   |                                                                              |===================================                                   |  50%
#> Warning: Failed to fetch page 299 - Status code: 429
#> Warning: Failed to fetch page 300 - Status code: 429
#> Warning: Failed to fetch page 301 - Status code: 429
#> Warning: Failed to fetch page 302 - Status code: 429
#> Warning: Failed to fetch page 303 - Status code: 429
#> Warning: Failed to fetch page 304 - Status code: 429
#> Warning: Failed to fetch page 305 - Status code: 429
#>   |                                                                              |===================================                                   |  51%
#> Warning: Failed to fetch page 306 - Status code: 429
#>   |                                                                              |====================================                                  |  51%
#> Warning: Failed to fetch page 307 - Status code: 429
#> Warning: Failed to fetch page 308 - Status code: 429
#> Warning: Failed to fetch page 309 - Status code: 429
#> Warning: Failed to fetch page 310 - Status code: 429
#> Warning: Failed to fetch page 311 - Status code: 429
#>   |                                                                              |====================================                                  |  52%
#> Warning: Failed to fetch page 312 - Status code: 429
#> Warning: Failed to fetch page 313 - Status code: 429
#> Warning: Failed to fetch page 314 - Status code: 429
#>   |                                                                              |=====================================                                 |  52%
#> Warning: Failed to fetch page 315 - Status code: 429
#> Warning: Failed to fetch page 316 - Status code: 429
#> Warning: Failed to fetch page 317 - Status code: 429
#>   |                                                                              |=====================================                                 |  53%
#> Warning: Failed to fetch page 318 - Status code: 429
#> Warning: Failed to fetch page 319 - Status code: 429
#> Warning: Failed to fetch page 320 - Status code: 429
#> Warning: Failed to fetch page 321 - Status code: 429
#> Warning: Failed to fetch page 322 - Status code: 429
#> Warning: Failed to fetch page 323 - Status code: 429
#>   |                                                                              |======================================                                |  54%
#> Warning: Failed to fetch page 324 - Status code: 429
#> Warning: Failed to fetch page 325 - Status code: 429
#> Warning: Failed to fetch page 326 - Status code: 429
#> Warning: Failed to fetch page 327 - Status code: 429
#> Warning: Failed to fetch page 328 - Status code: 429
#> Warning: Failed to fetch page 329 - Status code: 429
#>   |                                                                              |======================================                                |  55%
#> Warning: Failed to fetch page 330 - Status code: 429
#> Warning: Failed to fetch page 331 - Status code: 429
#> Warning: Failed to fetch page 332 - Status code: 429
#>   |                                                                              |=======================================                               |  55%
#> Warning: Failed to fetch page 333 - Status code: 429
#> Warning: Failed to fetch page 334 - Status code: 429
#> Warning: Failed to fetch page 335 - Status code: 429
#>   |                                                                              |=======================================                               |  56%
#> Warning: Failed to fetch page 336 - Status code: 429
#> Warning: Failed to fetch page 337 - Status code: 429
#> Warning: Failed to fetch page 338 - Status code: 429
#> Warning: Failed to fetch page 339 - Status code: 429
#> Warning: Failed to fetch page 340 - Status code: 429
#>   |                                                                              |========================================                              |  56%
#> Warning: Failed to fetch page 341 - Status code: 429
#>   |                                                                              |========================================                              |  57%
#> Warning: Failed to fetch page 342 - Status code: 429
#> Warning: Failed to fetch page 343 - Status code: 429
#> Warning: Failed to fetch page 344 - Status code: 429
#> Warning: Failed to fetch page 345 - Status code: 429
#> Warning: Failed to fetch page 346 - Status code: 429
#> Warning: Failed to fetch page 347 - Status code: 429
#>   |                                                                              |========================================                              |  58%
#> Warning: Failed to fetch page 348 - Status code: 429
#> Warning: Failed to fetch page 349 - Status code: 429
#>   |                                                                              |=========================================                             |  58%
#> Warning: Failed to fetch page 350 - Status code: 429
#> Warning: Failed to fetch page 351 - Status code: 429
#> Warning: Failed to fetch page 352 - Status code: 429
#> Warning: Failed to fetch page 353 - Status code: 429
#>   |                                                                              |=========================================                             |  59%
#> Warning: Failed to fetch page 354 - Status code: 429
#> Warning: Failed to fetch page 355 - Status code: 429
#> Warning: Failed to fetch page 356 - Status code: 429
#> Warning: Failed to fetch page 357 - Status code: 429
#>   |                                                                              |==========================================                            |  59%
#> Warning: Failed to fetch page 358 - Status code: 429
#> Warning: Failed to fetch page 359 - Status code: 429
#>   |                                                                              |==========================================                            |  60%
#> Warning: Failed to fetch page 360 - Status code: 429
#> Warning: Failed to fetch page 361 - Status code: 429
#> Warning: Failed to fetch page 362 - Status code: 429
#> Warning: Failed to fetch page 363 - Status code: 429
#> Warning: Failed to fetch page 364 - Status code: 429
#> Warning: Failed to fetch page 365 - Status code: 429
#>   |                                                                              |==========================================                            |  61%
#> Warning: Failed to fetch page 366 - Status code: 429
#>   |                                                                              |===========================================                           |  61%
#> Warning: Failed to fetch page 367 - Status code: 429
#> Warning: Failed to fetch page 368 - Status code: 429
#> Warning: Failed to fetch page 369 - Status code: 429
#> Warning: Failed to fetch page 370 - Status code: 429
#> Warning: Failed to fetch page 371 - Status code: 429
#>   |                                                                              |===========================================                           |  62%
#> Warning: Failed to fetch page 372 - Status code: 429
#> Warning: Failed to fetch page 373 - Status code: 429
#> Warning: Failed to fetch page 374 - Status code: 429
#> Warning: Failed to fetch page 375 - Status code: 429
#>   |                                                                              |============================================                          |  62%
#> Warning: Failed to fetch page 376 - Status code: 429
#> Warning: Failed to fetch page 377 - Status code: 429
#>   |                                                                              |============================================                          |  63%
#> Warning: Failed to fetch page 378 - Status code: 429
#> Warning: Failed to fetch page 379 - Status code: 429
#> Warning: Failed to fetch page 380 - Status code: 429
#> Warning: Failed to fetch page 381 - Status code: 429
#> Warning: Failed to fetch page 382 - Status code: 429
#> Warning: Failed to fetch page 383 - Status code: 429
#>   |                                                                              |=============================================                         |  64%
#> Warning: Failed to fetch page 384 - Status code: 429
#> Warning: Failed to fetch page 385 - Status code: 429
#> Warning: Failed to fetch page 386 - Status code: 429
#> Warning: Failed to fetch page 387 - Status code: 429
#> Warning: Failed to fetch page 388 - Status code: 429
#> Warning: Failed to fetch page 389 - Status code: 429
#>   |                                                                              |=============================================                         |  65%
#> Warning: Failed to fetch page 390 - Status code: 429
#> Warning: Failed to fetch page 391 - Status code: 429
#> Warning: Failed to fetch page 392 - Status code: 429
#>   |                                                                              |==============================================                        |  65%
#> Warning: Failed to fetch page 393 - Status code: 429
#> Warning: Failed to fetch page 394 - Status code: 429
#> Warning: Failed to fetch page 395 - Status code: 429
#>   |                                                                              |==============================================                        |  66%
#> Warning: Failed to fetch page 396 - Status code: 429
#> Warning: Failed to fetch page 397 - Status code: 429
#> Warning: Failed to fetch page 398 - Status code: 429
#> Warning: Failed to fetch page 399 - Status code: 429
#> Warning: Failed to fetch page 400 - Status code: 429
#>   |                                                                              |===============================================                       |  66%
#> Warning: Failed to fetch page 401 - Status code: 429
#>   |                                                                              |===============================================                       |  67%
#> Warning: Failed to fetch page 402 - Status code: 429
#> Warning: Failed to fetch page 403 - Status code: 429
#> Warning: Failed to fetch page 404 - Status code: 429
#> Warning: Failed to fetch page 405 - Status code: 429
#> Warning: Failed to fetch page 406 - Status code: 429
#> Warning: Failed to fetch page 407 - Status code: 429
#>   |                                                                              |===============================================                       |  68%
#> Warning: Failed to fetch page 408 - Status code: 429
#> Warning: Failed to fetch page 409 - Status code: 429
#>   |                                                                              |================================================                      |  68%
#> Warning: Failed to fetch page 410 - Status code: 429
#> Warning: Failed to fetch page 411 - Status code: 429
#> Warning: Failed to fetch page 412 - Status code: 429
#> Warning: Failed to fetch page 413 - Status code: 429
#>   |                                                                              |================================================                      |  69%
#> Warning: Failed to fetch page 414 - Status code: 429
#> Warning: Failed to fetch page 415 - Status code: 429
#> Warning: Failed to fetch page 416 - Status code: 429
#> Warning: Failed to fetch page 417 - Status code: 429
#> Warning: Failed to fetch page 418 - Status code: 429
#>   |                                                                              |=================================================                     |  69%
#> Warning: Failed to fetch page 419 - Status code: 429
#>   |                                                                              |=================================================                     |  70%
#> Warning: Failed to fetch page 420 - Status code: 429
#> Warning: Failed to fetch page 421 - Status code: 429
#> Warning: Failed to fetch page 422 - Status code: 429
#> Warning: Failed to fetch page 423 - Status code: 429
#> Warning: Failed to fetch page 424 - Status code: 429
#> Warning: Failed to fetch page 425 - Status code: 429
#>   |                                                                              |=================================================                     |  71%
#> Warning: Failed to fetch page 426 - Status code: 429
#>   |                                                                              |==================================================                    |  71%
#> Warning: Failed to fetch page 427 - Status code: 429
#> Warning: Failed to fetch page 428 - Status code: 429
#> Warning: Failed to fetch page 429 - Status code: 429
#> Warning: Failed to fetch page 430 - Status code: 429
#> Warning: Failed to fetch page 431 - Status code: 429
#>   |                                                                              |==================================================                    |  72%
#> Warning: Failed to fetch page 432 - Status code: 429
#> Warning: Failed to fetch page 433 - Status code: 429
#> Warning: Failed to fetch page 434 - Status code: 429
#> Warning: Failed to fetch page 435 - Status code: 429
#>   |                                                                              |===================================================                   |  72%
#> Warning: Failed to fetch page 436 - Status code: 429
#> Warning: Failed to fetch page 437 - Status code: 429
#>   |                                                                              |===================================================                   |  73%
#> Warning: Failed to fetch page 438 - Status code: 429
#> Warning: Failed to fetch page 439 - Status code: 429
#> Warning: Failed to fetch page 440 - Status code: 429
#> Warning: Failed to fetch page 441 - Status code: 429
#> Warning: Failed to fetch page 442 - Status code: 429
#> Warning: Failed to fetch page 443 - Status code: 429
#>   |                                                                              |====================================================                  |  74%
#> Warning: Failed to fetch page 444 - Status code: 429
#> Warning: Failed to fetch page 445 - Status code: 429
#> Warning: Failed to fetch page 446 - Status code: 429
#> Warning: Failed to fetch page 447 - Status code: 429
#> Warning: Failed to fetch page 448 - Status code: 429
#> Warning: Failed to fetch page 449 - Status code: 429
#>   |                                                                              |====================================================                  |  75%
#> Warning: Failed to fetch page 450 - Status code: 429
#> Warning: Failed to fetch page 451 - Status code: 429
#> Warning: Failed to fetch page 452 - Status code: 429
#>   |                                                                              |=====================================================                 |  75%
#> Warning: Failed to fetch page 453 - Status code: 429
#> Warning: Failed to fetch page 454 - Status code: 429
#> Warning: Failed to fetch page 455 - Status code: 429
#>   |                                                                              |=====================================================                 |  76%
#> Warning: Failed to fetch page 456 - Status code: 429
#> Warning: Failed to fetch page 457 - Status code: 429
#> Warning: Failed to fetch page 458 - Status code: 429
#> Warning: Failed to fetch page 459 - Status code: 429
#> Warning: Failed to fetch page 460 - Status code: 429
#> Warning: Failed to fetch page 461 - Status code: 429
#>   |                                                                              |======================================================                |  77%
#> Warning: Failed to fetch page 462 - Status code: 429
#> Warning: Failed to fetch page 463 - Status code: 429
#> Warning: Failed to fetch page 464 - Status code: 429
#> Warning: Failed to fetch page 465 - Status code: 429
#> Warning: Failed to fetch page 466 - Status code: 429
#> Warning: Failed to fetch page 467 - Status code: 429
#>   |                                                                              |======================================================                |  78%
#> Warning: Failed to fetch page 468 - Status code: 429
#> Warning: Failed to fetch page 469 - Status code: 429
#>   |                                                                              |=======================================================               |  78%
#> Warning: Failed to fetch page 470 - Status code: 429
#> Warning: Failed to fetch page 471 - Status code: 429
#> Warning: Failed to fetch page 472 - Status code: 429
#> Warning: Failed to fetch page 473 - Status code: 429
#>   |                                                                              |=======================================================               |  79%
#> Warning: Failed to fetch page 474 - Status code: 429
#> Warning: Failed to fetch page 475 - Status code: 429
#> Warning: Failed to fetch page 476 - Status code: 429
#> Warning: Failed to fetch page 477 - Status code: 429
#> Warning: Failed to fetch page 478 - Status code: 429
#>   |                                                                              |========================================================              |  79%
#> Warning: Failed to fetch page 479 - Status code: 429
#>   |                                                                              |========================================================              |  80%
#> Warning: Failed to fetch page 480 - Status code: 429
#> Warning: Failed to fetch page 481 - Status code: 429
#> Warning: Failed to fetch page 482 - Status code: 429
#> Warning: Failed to fetch page 483 - Status code: 429
#> Warning: Failed to fetch page 484 - Status code: 429
#> Warning: Failed to fetch page 485 - Status code: 429
#>   |                                                                              |========================================================              |  81%
#> Warning: Failed to fetch page 486 - Status code: 429
#>   |                                                                              |=========================================================             |  81%
#> Warning: Failed to fetch page 487 - Status code: 429
#> Warning: Failed to fetch page 488 - Status code: 429
#> Warning: Failed to fetch page 489 - Status code: 429
#> Warning: Failed to fetch page 490 - Status code: 429
#> Warning: Failed to fetch page 491 - Status code: 429
#>   |                                                                              |=========================================================             |  82%
#> Warning: Failed to fetch page 492 - Status code: 429
#> Warning: Failed to fetch page 493 - Status code: 429
#> Warning: Failed to fetch page 494 - Status code: 429
#> Warning: Failed to fetch page 495 - Status code: 429
#>   |                                                                              |==========================================================            |  82%
#> Warning: Failed to fetch page 496 - Status code: 429
#> Warning: Failed to fetch page 497 - Status code: 429
#>   |                                                                              |==========================================================            |  83%
#> Warning: Failed to fetch page 498 - Status code: 429
#> Warning: Failed to fetch page 499 - Status code: 429
#> Warning: Failed to fetch page 500 - Status code: 429
#> Warning: Failed to fetch page 501 - Status code: 429
#> Warning: Failed to fetch page 502 - Status code: 429
#> Warning: Failed to fetch page 503 - Status code: 429
#>   |                                                                              |==========================================================            |  84%
#> Warning: Failed to fetch page 504 - Status code: 429
#>   |                                                                              |===========================================================           |  84%
#> Warning: Failed to fetch page 505 - Status code: 429
#> Warning: Failed to fetch page 506 - Status code: 429
#> Warning: Failed to fetch page 507 - Status code: 429
#> Warning: Failed to fetch page 508 - Status code: 429
#> Warning: Failed to fetch page 509 - Status code: 429
#>   |                                                                              |===========================================================           |  85%
#> Warning: Failed to fetch page 510 - Status code: 429
#> Warning: Failed to fetch page 511 - Status code: 429
#> Warning: Failed to fetch page 512 - Status code: 429
#>   |                                                                              |============================================================          |  85%
#> Warning: Failed to fetch page 513 - Status code: 429
#> Warning: Failed to fetch page 514 - Status code: 429
#> Warning: Failed to fetch page 515 - Status code: 429
#>   |                                                                              |============================================================          |  86%
#> Warning: Failed to fetch page 516 - Status code: 429
#> Warning: Failed to fetch page 517 - Status code: 429
#> Warning: Failed to fetch page 518 - Status code: 429
#> Warning: Failed to fetch page 519 - Status code: 429
#> Warning: Failed to fetch page 520 - Status code: 429
#> Warning: Failed to fetch page 521 - Status code: 429
#>   |                                                                              |=============================================================         |  87%
#> Warning: Failed to fetch page 522 - Status code: 429
#> Warning: Failed to fetch page 523 - Status code: 429
#> Warning: Failed to fetch page 524 - Status code: 429
#> Warning: Failed to fetch page 525 - Status code: 429
#> Warning: Failed to fetch page 526 - Status code: 429
#> Warning: Failed to fetch page 527 - Status code: 429
#>   |                                                                              |=============================================================         |  88%
#> Warning: Failed to fetch page 528 - Status code: 429
#> Warning: Failed to fetch page 529 - Status code: 429
#>   |                                                                              |==============================================================        |  88%
#> Warning: Failed to fetch page 530 - Status code: 429
#> Warning: Failed to fetch page 531 - Status code: 429
#> Warning: Failed to fetch page 532 - Status code: 429
#> Warning: Failed to fetch page 533 - Status code: 429
#>   |                                                                              |==============================================================        |  89%
#> Warning: Failed to fetch page 534 - Status code: 429
#> Warning: Failed to fetch page 535 - Status code: 429
#> Warning: Failed to fetch page 536 - Status code: 429
#> Warning: Failed to fetch page 537 - Status code: 429
#> Warning: Failed to fetch page 538 - Status code: 429
#>   |                                                                              |===============================================================       |  89%
#> Warning: Failed to fetch page 539 - Status code: 429
#>   |                                                                              |===============================================================       |  90%
#> Warning: Failed to fetch page 540 - Status code: 429
#> Warning: Failed to fetch page 541 - Status code: 429
#> Warning: Failed to fetch page 542 - Status code: 429
#> Warning: Failed to fetch page 543 - Status code: 429
#> Warning: Failed to fetch page 544 - Status code: 429
#> Warning: Failed to fetch page 545 - Status code: 429
#>   |                                                                              |===============================================================       |  91%
#> Warning: Failed to fetch page 546 - Status code: 429
#> Warning: Failed to fetch page 547 - Status code: 429
#>   |                                                                              |================================================================      |  91%
#> Warning: Failed to fetch page 548 - Status code: 429
#> Warning: Failed to fetch page 549 - Status code: 429
#> Warning: Failed to fetch page 550 - Status code: 429
#> Warning: Failed to fetch page 551 - Status code: 429
#>   |                                                                              |================================================================      |  92%
#> Warning: Failed to fetch page 552 - Status code: 429
#> Warning: Failed to fetch page 553 - Status code: 429
#> Warning: Failed to fetch page 554 - Status code: 429
#> Warning: Failed to fetch page 555 - Status code: 429
#>   |                                                                              |=================================================================     |  92%
#> Warning: Failed to fetch page 556 - Status code: 429
#> Warning: Failed to fetch page 557 - Status code: 429
#>   |                                                                              |=================================================================     |  93%
#> Warning: Failed to fetch page 558 - Status code: 429
#> Warning: Failed to fetch page 559 - Status code: 429
#> Warning: Failed to fetch page 560 - Status code: 429
#> Warning: Failed to fetch page 561 - Status code: 429
#> Warning: Failed to fetch page 562 - Status code: 429
#> Warning: Failed to fetch page 563 - Status code: 429
#>   |                                                                              |=================================================================     |  94%
#> Warning: Failed to fetch page 564 - Status code: 429
#>   |                                                                              |==================================================================    |  94%
#> Warning: Failed to fetch page 565 - Status code: 429
#> Warning: Failed to fetch page 566 - Status code: 429
#> Warning: Failed to fetch page 567 - Status code: 429
#> Warning: Failed to fetch page 568 - Status code: 429
#> Warning: Failed to fetch page 569 - Status code: 429
#>   |                                                                              |==================================================================    |  95%
#> Warning: Failed to fetch page 570 - Status code: 429
#> Warning: Failed to fetch page 571 - Status code: 429
#> Warning: Failed to fetch page 572 - Status code: 429
#>   |                                                                              |===================================================================   |  95%
#> Warning: Failed to fetch page 573 - Status code: 429
#> Warning: Failed to fetch page 574 - Status code: 429
#> Warning: Failed to fetch page 575 - Status code: 429
#>   |                                                                              |===================================================================   |  96%
#> Warning: Failed to fetch page 576 - Status code: 429
#> Warning: Failed to fetch page 577 - Status code: 429
#> Warning: Failed to fetch page 578 - Status code: 429
#> Warning: Failed to fetch page 579 - Status code: 429
#> Warning: Failed to fetch page 580 - Status code: 429
#> Warning: Failed to fetch page 581 - Status code: 429
#>   |                                                                              |====================================================================  |  97%
#> Warning: Failed to fetch page 582 - Status code: 429
#> Warning: Failed to fetch page 583 - Status code: 429
#> Warning: Failed to fetch page 584 - Status code: 429
#> Warning: Failed to fetch page 585 - Status code: 429
#> Warning: Failed to fetch page 586 - Status code: 429
#> Warning: Failed to fetch page 587 - Status code: 429
#>   |                                                                              |====================================================================  |  98%
#> Warning: Failed to fetch page 588 - Status code: 429
#> Warning: Failed to fetch page 589 - Status code: 429
#> Warning: Failed to fetch page 590 - Status code: 429
#>   |                                                                              |===================================================================== |  98%
#> Warning: Failed to fetch page 591 - Status code: 429
#> Warning: Failed to fetch page 592 - Status code: 429
#> Warning: Failed to fetch page 593 - Status code: 429
#>   |                                                                              |===================================================================== |  99%
#> Warning: Failed to fetch page 594 - Status code: 429
#> Warning: Failed to fetch page 595 - Status code: 429
#> Warning: Failed to fetch page 596 - Status code: 429
#> Warning: Failed to fetch page 597 - Status code: 429
#> Warning: Failed to fetch page 598 - Status code: 429
#>   |                                                                              |======================================================================|  99%
#> Warning: Failed to fetch page 599 - Status code: 429
#>   |                                                                              |======================================================================| 100%
#> Warning: Failed to fetch page 600 - Status code: 429
#> Warning: Failed to fetch page 601 - Status code: 429
#> Warning: Failed to fetch page 602 - Status code: 429
#> 

# Get the full dataset directly from the CSV endpoint
killed_from_csv = gaza_killed(format = "csv")
#> Fetching data from: https://data.techforpalestine.org/api/v2/killed-in-gaza.csv
#> Warning: Failed to open 'https://data.techforpalestine.org/api/v2/killed-in-gaza.csv': The requested URL returned error: 429
#> Error: cannot open the connection

# Get a specific page
page_1 = gaza_killed(format = "page", page = 1)
#> Fetching page 1 from: https://data.techforpalestine.org/api/v2/killed-in-gaza/page-1.json
#> Error in gaza_killed(format = "page", page = 1): Failed to fetch page 1 . Status code: 429

# Get without progress bar
data = gaza_killed(progress = FALSE)
#> Fetching summary data from: https://data.techforpalestine.org/api/v3/summary.min.json
#> Error in gaza_summary_data(): Failed to fetch summary data. Status code: 429
```
