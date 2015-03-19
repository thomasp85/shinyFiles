#' Adds the content of www to sF/
#' 
#' @importFrom shiny addResourcePath
#' 
#' @noRd
#' 
.onAttach <- function(...) {
    addResourcePath('sF', system.file('www', package='shinyFiles'))
}

#' Run a simple example app using the shinyFiles functionality
#' 
#' When the function is invoked a shiny app is started showing a very simple 
#' setup using shinyFiles. A button summons the dialog box allowing the user to
#' navigate the R installation directory. To showcase the restrictions parameter
#' the base package location has been hidden, and is thus inaccecible. A panel 
#' besides the button shows how the user selection is made accessible to the 
#' server after parsing with \code{\link{parseFilePaths}}.
#' 
#' @family shinyFiles
#' 
#' @importFrom shiny runApp
#' 
#' @export
#' 
shinyFilesExample <- function() {
    runApp(system.file('example', package='shinyFiles', mustWork=T), display.mode='showcase')
}
#' Get a list of available volumes
#' 
#' This function is intended as an input to the roots parameter in 
#' \code{\link{fileGetter}} and \code{\link{shinyFileChoose}}. It returns a
#' function that returns a named vector of available volumes on the system. This
#' construction makes it dynamic so that a shinyFiles instance reflects new
#' volumes as they get added (e.g. usb drives). The function takes a single
#' argument giving names of volumes the developer wants removed from the return
#' value.
#' 
#' @details
#' The function is OS specific and looks for volumes/drives in different places
#' depending on the system on which shiny is running.
#' \describe{
#'  \item{Windows}{Returns all drives mapped to a letter}
#'  \item{Mac OSX}{Looks in /Volumes/ and lists the directories therein}
#'  \item{Linux}{Returns the system root}
#' }
#' If the function does not recognize the system under which it is running it 
#' will throw an error
#' 
#' @param exclude A vector of volume names to be excluded from the return value
#' 
#' @return A function returning a named vector of available volumes
#' 
#' @export
#' 
getVolumes <- function(exclude) {
    if(missing(exclude)) exclude <- NULL
    
    function() {
        osSystem <- Sys.info()['sysname']
        if (osSystem == 'Darwin') {
            volumes <- list.files('/Volumes/', full.names=T)
            names(volumes) <- basename(volumes)
        } else if (osSystem == 'Linux') {
            volumes <- c('Computer'='/')
            media <- list.files('/media/', full.names=T)
            names(media) <- basename(media)
            volumes <- c(volumes, media)
        } else if (osSystem == 'Windows') {
            volumes <- system('wmic logicaldisk get Caption', intern=T)
            volumes <- sub(' *\\r$', '', volumes)
            keep <- !tolower(volumes) %in% c('caption', '')
            volumes <- volumes[keep]
            volNames <- system('wmic logicaldisk get VolumeName', intern=T)
            volNames <- sub(' *\\r$', '', volNames)
            volNames <- volNames[keep]
            volNames <- paste0(volNames, ' (', volumes, ')')
            names(volumes) <- volNames
        } else {
            stop('unsupported OS')
        }
        if (!is.null(exclude)) {
            volumes <- volumes[!names(volumes) %in% exclude]
        }
        volumes
    }
}