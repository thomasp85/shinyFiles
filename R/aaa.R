#' Adds the content of www to sF/
#' 
#' @importFrom shiny addResourcePath
#' 
.onAttach <- function(...) {
    addResourcePath('sF', system.file('www', package='shinyFiles'))
}