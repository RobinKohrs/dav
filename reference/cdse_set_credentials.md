# Set Copernicus Data Space Ecosystem Credentials

Reads AWS credentials from the standard AWS credentials file
(`~/.aws/credentials`) for a specific profile (defaulting to
"copernicus").

## Usage

``` r
cdse_set_credentials(profile = "copernicus", file = "~/.aws/credentials")
```

## Arguments

- profile:

  Character. The name of the profile to read from the credentials file.
  Defaults to "copernicus".

- file:

  Character. Path to the AWS credentials file. Defaults to
  "~/.aws/credentials".

## Value

A named list containing `access_key` and `secret_key`, or NULL if not
found.
