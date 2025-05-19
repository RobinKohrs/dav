#' @title List Parameters for a Given Resource
#' @description This function lists the parameters available for a given resource.
#' @param resource_id The ID of the resource to list parameters for.
#' @return A vector of parameter names.
#' @export
#' @importFrom httr GET modify_url stop_for_status content
#' @importFrom jsonlite fromJSON
geosphere_list_params = function(resource_id) {
    # get the metadata
    metadata = geosphere_get_metadata(resource_id)
    return(metadata$parameters)
}
