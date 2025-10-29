#' Compare multiple vectors
#'
#' This function takes multiple vectors as input and returns a data frame
#' showing the presence or absence of each unique element across all vectors.
#'
#' @param ... A variable number of vectors to compare.
#' @return A data frame with a column 'element' containing all unique elements
#'   from the input vectors. For each input vector, a logical column 'in_vector_i'
#'   is added, indicating if the element is present in that vector. An additional
#'   column 'in_all' is TRUE if the element is present in all vectors.
#' @export
#' @examples
#' vec1 <- c("a", "b", "c")
#' vec2 <- c("b", "c", "d")
#' vec3 <- c("c", "d", "e")
#' dav_compare(vec1, vec2, vec3)
dav_compare <- function(...) {
    vec_list <- list(...) # list of input vectors
    all_elems <- unique(unlist(vec_list)) # all unique elements

    # initialize result
    res <- data.frame(element = all_elems, stringsAsFactors = FALSE)

    # for each vector, check presence
    for (i in seq_along(vec_list)) {
        res[[paste0("in_vector_", i)]] <- all_elems %in% vec_list[[i]]
    }

    # in_all column
    res$in_all <- apply(res[, -1], 1, all)

    return(res)
}
