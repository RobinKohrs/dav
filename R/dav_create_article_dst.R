#' Create a derstandard.at-styled Quarto Article
#'
#' Creates a directory containing a Quarto HTML article (`article.qmd`) and a
#' CSS file (`article-dst.css`) that together reproduce the visual identity of
#' derstandard.at, using the STMatilda font family and ressort-specific accent
#' colours.
#'
#' @param ressort Character string. The derstandard.at ressort (section). Must
#'   be one of `"Inland"`, `"Ausland"`, `"Wirtschaft"`, `"Web"`, `"Sport"`,
#'   `"Panorama"`, `"Wissenschaft"`, `"Technik"`, `"Kultur"`, `"Etat"`,
#'   `"Karriere"`, `"Immobilien"`, `"Genuss"`, `"Recht"`, `"Diskurs"`,
#'   `"Album"`, `"Dossier"`. Falls back to the Standard red for unknown values.
#' @param article_directory Character string. Path to the directory that will
#'   be created. Both the `article.qmd` and `article-dst.css` files are placed
#'   directly inside this directory.
#' @param title Character string. Article headline displayed in the dark header
#'   and used as the HTML page title.
#' @param subtitle Character string. Article standfirst / lead text displayed
#'   below the headline in the dark header.
#' @param author Character string. Author name shown in the byline.
#'   Defaults to an empty string (byline line is still rendered).
#' @param overwrite Logical. If `FALSE` (the default), an existing
#'   `article.qmd` is left untouched — only `article-dst.css` is updated. Set
#'   to `TRUE` to also regenerate the QMD (this will discard any content you
#'   have written in the file).
#'
#' @return Invisibly returns the path to the `article.qmd` file.
#' @export
#'
#' @examples
#' \dontrun{
#' dav_create_article_dst(
#'   ressort          = "Wirtschaft",
#'   article_directory = "articles/pkw-elektro-2025",
#'   title            = "Der Elektroauto-Boom stockt",
#'   subtitle         = "Trotz sinkender Preise sinken die Zulassungszahlen – was steckt dahinter?"
#' )
#' }
dav_create_article_dst <- function(ressort,
                                   article_directory,
                                   title,
                                   subtitle,
                                   author = "",
                                   overwrite = FALSE) {

  # ── ressort → accent colour ──────────────────────────────────────────────────
  .RESSORT_COLORS <- c(
    "Inland"       = "#CC0015",
    "Ausland"      = "#0052A2",
    "Wirtschaft"   = "#D8DEC1",
    "Web"          = "#0066CC",
    "Technik"      = "#0066CC",
    "Sport"        = "#2B8C4E",
    "Panorama"     = "#CC0015",
    "Wissenschaft" = "#5B2D8E",
    "Kultur"       = "#8B1A6B",
    "Album"        = "#8B1A6B",
    "Etat"         = "#CC0015",
    "Medien"       = "#CC0015",
    "Karriere"     = "#D46000",
    "Immobilien"   = "#D46000",
    "Genuss"       = "#A0522D",
    "Recht"        = "#2C3E7A",
    "Diskurs"      = "#4A4A4A",
    "Dossier"      = "#CC0015",
    "Zukunft"      = "#E6E6E6"
  )

  accent_color <- if (ressort %in% names(.RESSORT_COLORS)) {
    .RESSORT_COLORS[[ressort]]
  } else {
    cli::cli_alert_warning(
      "Unknown ressort {.val {ressort}}. Using default Standard red."
    )
    "#CC0015"
  }

  # ── create directory ─────────────────────────────────────────────────────────
  dir.create(article_directory, recursive = TRUE, showWarnings = FALSE)

  # ── CSS ──────────────────────────────────────────────────────────────────────
  css_content <- .dst_css()

  writeLines(css_content, con = file.path(article_directory, "article-dst.css"))

  # ── QMD ──────────────────────────────────────────────────────────────────────
  qmd_path <- file.path(article_directory, "article.qmd")
  qmd_exists <- file.exists(qmd_path)

  if (!qmd_exists || overwrite) {
    qmd_content <- .dst_qmd(
      title        = title,
      subtitle     = subtitle,
      ressort      = ressort,
      accent_color = accent_color,
      author       = author
    )
    writeLines(qmd_content, con = qmd_path)
    cli::cli_alert_success("Artikel erstellt: {.path {qmd_path}}")
  } else {
    cli::cli_alert_success("CSS aktualisiert (article.qmd unveraendert): {.path {qmd_path}}")
    cli::cli_alert_info(
      "Verwende {.code overwrite = TRUE} um auch das QMD neu zu erstellen."
    )
  }

  cli::cli_bullets(c(
    " " = "Ressort: {.val {ressort}} ({accent_color})",
    " " = "Rendern mit: {.code quarto render {qmd_path}}"
  ))

  invisible(qmd_path)
}


# ── internal helpers ──────────────────────────────────────────────────────────

.dst_qmd <- function(title, subtitle, ressort, accent_color, author = "") {
  paste0(
'---
pagetitle: "', title, '"
lang: de
format:
  html:
    css: article-dst.css
    toc: false
    embed-resources: true
    page-layout: custom
---

```{=html}
<style>
  :root, body {
    --ressort-color: ', accent_color, ';
    --quarto-body-bg: ', accent_color, ';
  }
  body { background-color: ', accent_color, ' !important; }
</style>
<header class="dst-header">
  <div class="dst-ressort-badge">', toupper(ressort), '</div>
  <h1 class="dst-title">', title, '</h1>
  <p class="dst-subtitle">', subtitle, '</p>
</header>
```

::: {.dst-article}

::: {.dst-byline}
', if (nchar(author) > 0) paste0('*', author, '*') else '*DER STANDARD*', ' \u00b7 ', format(Sys.Date(), "%d. %B %Y"), '
:::

Einleitungstext des Artikels hier einf\u00fcgen.

## Zwischentitel

Weiterer Text hier.

:::
'
  )
}


.dst_css <- function() {
'/* =============================================================================
   derstandard.at Article Template
   STMatilda Font System — stylingtoolkit v6.0.1
   ============================================================================= */

/* --------------------------------------------------------------------------- */
/*  Font faces                                                                  */
/* --------------------------------------------------------------------------- */

@font-face {
	font-display: swap;
	font-family: "STMatilda Info Variable";
	font-style: normal;
	font-weight: 200 900;
	src: url("https://b.staticfiles.at/s/fonts/stmatilda/v1/stmatilda-info.woff2")
		format("woff2-variations");
	unicode-range: U+000A, U+0020-002F, U+0030-0039, U+003A-0040, U+0041-005A,
		U+005B-0060, U+0061-007A, U+007B-007E, U+2013, U+203A, U+2026, U+201E,
		U+201C, U+00A9, U+20AC, U+00C0-00FF, U+1E9E, U+011E, U+011F, U+0160,
		U+0161, U+201A, U+2018, U+00A0-00A8, U+00AA-00BF, U+0100-011D,
		U+0120-0148, U+014A-015F, U+0162-017F, U+0180-01BF, U+0200-0217,
		U+0218-021B, U+1F5E9;
}

@font-face {
	font-display: swap;
	font-family: "STMatilda Info Variable";
	font-style: italic;
	font-weight: 200 900;
	src: url("https://b.staticfiles.at/s/fonts/stmatilda/v1/stmatilda-info-italic.woff2")
		format("woff2-variations");
	unicode-range: U+000A, U+0020-002F, U+0030-0039, U+003A-0040, U+0041-005A,
		U+005B-0060, U+0061-007A, U+007B-007E, U+2013, U+203A, U+2026, U+201E,
		U+201C, U+00A9, U+20AC, U+00C0-00FF, U+1E9E, U+011E, U+011F, U+0160,
		U+0161, U+201A, U+2018, U+00A0-00A8, U+00AA-00BF, U+0100-011D,
		U+0120-0148, U+014A-015F, U+0162-017F, U+0180-01BF, U+0200-0217,
		U+0218-021B, U+1F5E9;
}

@font-face {
	font-display: swap;
	font-family: "STMatilda Text Variable";
	font-style: normal;
	font-weight: 300 700;
	src: url("https://b.staticfiles.at/s/fonts/stmatilda/v1/stmatilda-text.woff2")
		format("woff2-variations");
	unicode-range: U+000A, U+0020-002F, U+0030-0039, U+003A-0040, U+0041-005A,
		U+005B-0060, U+0061-007A, U+007B-007E, U+2013, U+203A, U+2026, U+201E,
		U+201C, U+00A9, U+20AC, U+00C0-00FF, U+1E9E, U+011E, U+011F, U+0160,
		U+0161, U+201A, U+2018, U+00A0-00A8, U+00AA-00BF, U+0100-011D,
		U+0120-0148, U+014A-015F, U+0162-017F, U+0180-01BF, U+0200-0217,
		U+0218-021B;
}

@font-face {
	font-display: swap;
	font-family: "STMatilda Text Variable";
	font-style: italic;
	font-weight: 300 700;
	src: url("https://b.staticfiles.at/s/fonts/stmatilda/v1/stmatilda-text-italic.woff2")
		format("woff2-variations");
	unicode-range: U+000A, U+0020-002F, U+0030-0039, U+003A-0040, U+0041-005A,
		U+005B-0060, U+0061-007A, U+007B-007E, U+2013, U+203A, U+2026, U+201E,
		U+201C, U+00A9, U+20AC, U+00C0-00FF, U+1E9E, U+011E, U+011F, U+0160,
		U+0161, U+201A, U+2018, U+00A0-00A8, U+00AA-00BF, U+0100-011D,
		U+0120-0148, U+014A-015F, U+0162-017F, U+0180-01BF, U+0200-0217,
		U+0218-021B;
}

@font-face {
	font-display: swap;
	font-family: "STMatilda Titel Variable";
	font-style: normal;
	font-weight: 100 900;
	src: url("https://b.staticfiles.at/s/fonts/stmatilda/v1/stmatilda-titel.woff2")
		format("woff2-variations");
	unicode-range: U+000A, U+0020-002F, U+0030-0039, U+003A-0040, U+0041-005A,
		U+005B-0060, U+0061-007A, U+007B-007E, U+2013, U+203A, U+2026, U+201E,
		U+201C, U+00A9, U+20AC, U+00C0-00FF, U+1E9E, U+011E, U+011F, U+0160,
		U+0161, U+201A, U+2018, U+00A0-00A8, U+00AA-00BF, U+0100-011D,
		U+0120-0148, U+014A-015F, U+0162-017F, U+0180-01BF, U+0200-0217,
		U+0218-021B;
}

@font-face {
	font-display: swap;
	font-family: "STMatilda Titel Variable";
	font-style: italic;
	font-weight: 100 900;
	src: url("https://b.staticfiles.at/s/fonts/stmatilda/v1/stmatilda-titel-italic.woff2")
		format("woff2-variations");
	unicode-range: U+000A, U+0020-002F, U+0030-0039, U+003A-0040, U+0041-005A,
		U+005B-0060, U+0061-007A, U+007B-007E, U+2013, U+203A, U+2026, U+201E,
		U+201C, U+00A9, U+20AC, U+00C0-00FF, U+1E9E, U+011E, U+011F, U+0160,
		U+0161, U+201A, U+2018, U+00A0-00A8, U+00AA-00BF, U+0100-011D,
		U+0120-0148, U+014A-015F, U+0162-017F, U+0180-01BF, U+0200-0217,
		U+0218-021B;
}

@font-face {
	font-display: swap;
	font-family: "STMatilda Grande Variable";
	font-style: normal;
	font-weight: 100 900;
	src: url("https://b.staticfiles.at/s/fonts/stmatilda/v1/stmatilda-grande.woff2")
		format("woff2-variations");
	unicode-range: U+000A, U+0020-002F, U+0030-0039, U+003A-0040, U+0041-005A,
		U+005B-0060, U+0061-007A, U+007B-007E, U+2013, U+203A, U+2026, U+201E,
		U+201C, U+00A9, U+20AC, U+00C0-00FF, U+1E9E, U+011E, U+011F, U+0160,
		U+0161, U+201A, U+2018, U+00A0-00A8, U+00AA-00BF, U+0100-011D,
		U+0120-0148, U+014A-015F, U+0162-017F, U+0180-01BF, U+0200-0217,
		U+0218-021B;
}

@font-face {
	font-display: swap;
	font-family: "STMatilda Brand";
	font-style: normal;
	font-weight: 400;
	src: url("https://b.staticfiles.at/s/fonts/stmatilda/v1/stmatilda-brand.woff2")
		format("woff2");
	unicode-range: U+000A, U+0020-00A0, U+00A9, U+00AB, U+00AC, U+00AD, U+00AE,
		U+00AF, U+00B0, U+00B4, U+00B6, U+00B7, U+00BB, U+00C4, U+00D6, U+00D7,
		U+00DC, U+00DF, U+00E4, U+00F6, U+00FC, U+0394, U+1E9E, U+2009-201E,
		U+2022-2044, U+20AC, U+2212, U+FB01, U+FB02;
}

/* --------------------------------------------------------------------------- */
/*  Reset Quarto defaults                                                       */
/* --------------------------------------------------------------------------- */

body {
  margin: 0;
  padding: 0;
  background-color: var(--ressort-color);
  color: #1a1a1a;
}

/* hide Quarto title block (we use custom header instead) */
#title-block-header,
.quarto-title-block {
  display: none !important;
}

/* with page-layout: custom there is no grid — reset any leftover padding */
.page-layout-custom {
  padding: 0 !important;
  margin: 0 !important;
  max-width: 100% !important;
}

/* --------------------------------------------------------------------------- */
/*  Article header                                                              */
/* --------------------------------------------------------------------------- */

.dst-header {
  /* page-layout: custom — no grid, so width: 100% is truly full-width */
  width: 100%;
  box-sizing: border-box;
  background: linear-gradient(
    135deg,
    #141414 0%,
    color-mix(in srgb, var(--ressort-color) 35%, #111111) 100%
  );
  color: #ffffff;
  padding: 40px 24px 44px;
}

@media (min-width: 700px) {
  .dst-header {
    padding: 56px calc((100% - 615px) / 2) 60px;
  }
}

.dst-ressort-badge {
  display: inline-block;
  font-family: "STMatilda Info Variable", system-ui, sans-serif;
  font-size: 0.75rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  color: var(--ressort-color);
  margin-bottom: 14px;
}

.dst-title {
  font-family: "STMatilda Info Variable", system-ui, sans-serif;
  font-size: 36px;
  font-weight: 800;
  line-height: 1.1;
  color: #ffffff;
  margin: 0 0 16px;
  padding: 0;
  border: none;
}

.dst-subtitle {
  font-family: "STMatilda Info Variable", system-ui, sans-serif;
  font-size: 19px;
  font-weight: 420;
  line-height: 1.4;
  color: rgba(255, 255, 255, 0.82);
  margin: 0;
  padding: 0;
}

/* --------------------------------------------------------------------------- */
/*  Article body                                                                */
/* --------------------------------------------------------------------------- */

.dst-article {
  max-width: 615px;
  margin: 0 auto;
  padding: 32px 24px 64px;
  font-family: "STMatilda Text Variable", system-ui, serif;
  font-size: 18px;
  font-weight: 420;
  line-height: 1.6;
  color: #1a1a1a;
}

@media (min-width: 640px) {
  .dst-article {
    padding: 40px 32px 80px;
  }
}

.dst-byline {
  font-family: "STMatilda Info Variable", system-ui, sans-serif;
  font-size: 0.8125rem;
  font-weight: 420;
  color: #666;
  margin-bottom: 28px;
  padding-bottom: 16px;
  border-bottom: 1px solid #e5e5e5;
}

.dst-article p {
  margin: 0 0 1.4em;
}

.dst-article h2 {
  font-family: "STMatilda Info Variable", system-ui, sans-serif;
  font-size: 1.375rem;
  font-weight: 700;
  line-height: 1.2;
  margin: 2em 0 0.6em;
  color: #111;
}

.dst-article h3 {
  font-family: "STMatilda Info Variable", system-ui, sans-serif;
  font-size: 1.125rem;
  font-weight: 700;
  line-height: 1.2;
  margin: 1.6em 0 0.5em;
  color: #111;
}

.dst-article a {
  color: #111;
  text-decoration: underline;
  text-underline-offset: 3px;
}

.dst-article a:hover {
  color: #CC0015;
}

.dst-article figure {
  margin: 2em 0;
}

.dst-article figure img {
  width: 100%;
  height: auto;
  display: block;
}

.dst-article figcaption {
  font-family: "STMatilda Info Variable", system-ui, sans-serif;
  font-size: 0.8125rem;
  font-weight: 420;
  color: #666;
  margin-top: 8px;
}

.dst-article blockquote {
  border-left: 3px solid #CC0015;
  margin: 1.6em 0;
  padding: 0.2em 0 0.2em 1.2em;
  font-style: italic;
  color: #333;
}

/* charts / visualisation containers */
.dst-chart {
  margin: 2em 0;
}

/* --------------------------------------------------------------------------- */
/*  Code blocks — minimal styling                                               */
/* --------------------------------------------------------------------------- */

.dst-article pre {
  background: #f5f5f5;
  border-radius: 4px;
  padding: 1em;
  overflow-x: auto;
  font-size: 0.875rem;
}

.dst-article code {
  font-size: 0.875em;
  background: #f0f0f0;
  padding: 0.1em 0.3em;
  border-radius: 3px;
}

.dst-article pre code {
  background: none;
  padding: 0;
}
'
}
