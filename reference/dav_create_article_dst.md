# Create a derstandard.at-styled Quarto Article

Creates a directory containing a Quarto HTML article (`article.qmd`) and
a CSS file (`article-dst.css`) that together reproduce the visual
identity of derstandard.at, using the STMatilda font family and
ressort-specific accent colours.

## Usage

``` r
dav_create_article_dst(
  ressort,
  article_directory,
  title,
  subtitle,
  author = "",
  overwrite = FALSE
)
```

## Arguments

- ressort:

  Character string. The derstandard.at ressort (section). Must be one of
  `"Inland"`, `"Ausland"`, `"Wirtschaft"`, `"Web"`, `"Sport"`,
  `"Panorama"`, `"Wissenschaft"`, `"Technik"`, `"Kultur"`, `"Etat"`,
  `"Karriere"`, `"Immobilien"`, `"Genuss"`, `"Recht"`, `"Diskurs"`,
  `"Album"`, `"Dossier"`. Falls back to the Standard red for unknown
  values.

- article_directory:

  Character string. Path to the directory that will be created. Both the
  `article.qmd` and `article-dst.css` files are placed directly inside
  this directory.

- title:

  Character string. Article headline displayed in the dark header and
  used as the HTML page title.

- subtitle:

  Character string. Article standfirst / lead text displayed below the
  headline in the dark header.

- author:

  Character string. Author name shown in the byline. Defaults to an
  empty string (byline line is still rendered).

- overwrite:

  Logical. If `FALSE` (the default), an existing `article.qmd` is left
  untouched — only `article-dst.css` is updated. Set to `TRUE` to also
  regenerate the QMD (this will discard any content you have written in
  the file).

## Value

Invisibly returns the path to the `article.qmd` file.

## Examples

``` r
if (FALSE) { # \dontrun{
dav_create_article_dst(
  ressort          = "Wirtschaft",
  article_directory = "articles/pkw-elektro-2025",
  title            = "Der Elektroauto-Boom stockt",
  subtitle         = "Trotz sinkender Preise sinken die Zulassungszahlen – was steckt dahinter?"
)
} # }
```
