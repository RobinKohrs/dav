% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sys_make_path.R
\name{sys_make_path}
\alias{sys_make_path}
\title{Ensure Directory Structure Exists (Custom Heuristic for File/Directory)}
\usage{
sys_make_path(path, showWarnings = FALSE, mode = "0777")
}
\arguments{
\item{path}{A character string specifying the full path.}

\item{showWarnings}{Logical. Passed to \code{dir.create()}. Defaults to \code{FALSE}.}

\item{mode}{Character. The mode for \code{dir.create()}. Defaults to \code{"0777"}.}
}
\value{
The original input \code{path}, returned invisibly.
}
\description{
Creates the necessary directory structure. It uses a custom heuristic to
determine if the input \code{path} is intended as a file or a directory.
}
\details{
The function's heuristic is as follows:
\enumerate{
\item If \code{path} already exists:
\itemize{
\item If it's a directory (per \code{file.info()}), no creation action is taken for it.
\item If it's a file (per \code{file.info()}), its parent directory is targeted for creation.
}
\item If \code{path} does not exist:
\itemize{
\item If the original \code{path} string ends with one or more path separators ('/' or '\'),
the full \code{path} is treated as a directory to be created.
\item Else, if the last component (basename) of the \code{path} does \emph{not} contain a
dot ('.'), the full \code{path} is treated as a directory to be created.
\item Otherwise (does not end with a separator AND basename contains a dot),
it's treated as a file path, and its parent directory is targeted for creation.
Provides console feedback using the cli package.
}
}
}
