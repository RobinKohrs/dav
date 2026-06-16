# Fetch Files from a GitLab Repository Directory

This function lists files in a specific directory of a GitLab repository
and optionally downloads them.

## Usage

``` r
gitlab_fetch_dir(
  gitlab_url,
  project_id,
  repo_path,
  branch,
  download = FALSE,
  output_dir = "gitlab_downloads",
  private_token = NULL
)
```

## Arguments

- gitlab_url:

  The base URL of the GitLab instance (e.g., "https://gitlab.com").

- project_id:

  The ID or URL-encoded path of the project (e.g., "group/project").

- repo_path:

  The path inside the repository to list/download files from.

- branch:

  The name of the branch.

- download:

  Logical. If TRUE, files will be downloaded. Default is FALSE.

- output_dir:

  The directory where files should be saved if download is TRUE. Default
  is "gitlab_downloads".

- private_token:

  An optional private token for accessing private repositories.

## Value

A data frame with the list of files (invisibly if downloaded), or NULL
if the request fails.

## Examples

``` r
if (FALSE) { # \dontrun{
# List files
files <- gitlab_fetch_dir(
  gitlab_url = "https://gitlab.com",
  project_id = "mygroup/myproject",
  repo_path = "data",
  branch = "main"
)

# Download files
gitlab_fetch_dir(
  gitlab_url = "https://gitlab.com",
  project_id = "mygroup/myproject",
  repo_path = "data",
  branch = "main",
  download = TRUE,
  output_dir = "my_data"
)
} # }
```
