# List Files in a GitLab Repository Recursively

This function lists all files in a given path of a GitLab repository
recursively. It uses the GitLab API to fetch the repository tree.

## Usage

``` r
gitlab_list_repo(
  gitlab_url,
  project_id,
  path = "",
  branch = "",
  private_token = NULL
)
```

## Arguments

- gitlab_url:

  The base URL of the GitLab instance (e.g., "https://gitlab.com").

- project_id:

  The ID or URL-encoded path of the project (e.g., "group/project" or
  "group%2Fproject").

- path:

  The path inside the repository to list files from. Default is the root
  ("").

- branch:

  The name of the branch. Default is the repository's default branch.

- private_token:

  An optional private token for accessing private repositories.

## Value

A data frame with the list of files and their attributes, or NULL if the
request fails.

## Examples

``` r
if (FALSE) { # \dontrun{
# List files in a public repository on gitlab.com
files_df <- gitlab_list_repo(
  gitlab_url = "https://gitlab.com",
  project_id = "gnome/nautilus"
)

if (!is.null(files_df)) {
  print(head(files_df))
}

# List files in a sub-directory of a project
files_in_src <- gitlab_list_repo(
  gitlab_url = "https://gitlab.com",
  project_id = "gnome/nautilus",
  path = "src"
)

if (!is.null(files_in_src)) {
  print(head(files_in_src))
}
} # }
```
