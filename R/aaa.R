#' Adds the content of www to sF/
#' 
#' @importFrom shiny addResourcePath
#' 
#' @noRd
#' 
.onAttach <- function(...) {
    addResourcePath('sF', system.file('www', package='shinyFiles'))
}