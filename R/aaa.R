#' Adds the content of www to sF/
#'
#' @importFrom shiny addResourcePath
#'
#' @noRd
#'
.onLoad <- function(...) {
  shiny::addResourcePath("sF", system.file("www", package = "shinyFiles"))
}

#' check for NULL or NA
#'
#' @noRd
#'
.is_not <- function(x) length(x) == 0 || (length(x) == 1 && is.na(x))

#' Run a simple example app using the shinyFiles functionality
#'
#' When the function is invoked a shiny app is started showing a very simple
#' setup using shinyFiles. A button summons the dialog box allowing the user to
#' navigate the R installation directory. To showcase the restrictions parameter
#' the base package location has been hidden, and is thus inaccessible. A panel
#' besides the button shows how the user selection is made accessible to the
#' server after parsing with [parseFilePaths()].
#'
#' @family shinyFiles
#'
#' @importFrom shiny runApp
#'
#' @export
#'
shinyFilesExample <- function() {
  shiny::runApp(system.file("example", package = "shinyFiles", mustWork = T), display.mode = "showcase")
}
#' Get a list of available volumes
#'
#' This function is intended as an input to the roots parameter in
#' [fileGetter()] and [shinyFileChoose()]. It returns a
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
#' @importFrom fs dir_exists dir_ls 
#'
#' @export
#'
getVolumes <- function(exclude) {
  if (missing(exclude)) exclude <- NULL

  function() {
    osSystem <- Sys.info()["sysname"]
    if (osSystem == "Darwin") {
      volumes <- dir_ls("/Volumes")
      names(volumes) <- basename(volumes)
    } else if (osSystem == "Linux") {
      volumes <- c("Computer" = "/")
      if (isTRUE(dir_exists("/media"))) {
        media <- dir_ls("/media")
        names(media) <- basename(media)
        volumes <- c(volumes, media)
      }
    } else if (osSystem == "Windows") {
      wmic <- paste0(Sys.getenv("SystemRoot"), "\\System32\\Wbem\\WMIC.exe")
      if (!file.exists(wmic)) {
        volumes_info <- system2("powershell", "$dvr=[System.IO.DriveInfo]::GetDrives();Write-Output $dvr.length $dvr.name $dvr.VolumeLabel;", stdout = TRUE)
        num = as.integer(volumes_info[1])
        if(num == 0) return(NULL)
        mat <- matrix(volumes_info[-1], nrow = num, ncol = 2)
        mat[, 1] <- gsub(":\\\\$", ":/", mat[, 1])
        sel <- mat[, 2] == ""
        mat[sel, 2] <- mat[sel, 1]
        volumes <- mat[, 1]
        volNames <- mat[, 2]
        volNames <- paste0(volNames, " (", gsub(":/$", ":", volumes), ")")
      } else {
        volumes <- system(paste(wmic, "logicaldisk get Caption"), intern = TRUE, ignore.stderr=TRUE)
        volumes <- sub(" *\\r$", "", volumes)
        keep <- !tolower(volumes) %in% c("caption", "")
        volumes <- volumes[keep]
        volNames <- system(paste(wmic, "/FAILFAST:1000 logicaldisk get VolumeName"), intern = TRUE, ignore.stderr=TRUE)
        volNames <- sub(" *\\r$", "", volNames)
        volNames <- volNames[keep]
        volNames <- paste0(volNames, ifelse(volNames == "", "", " "))
        volNames <- paste0(volNames, "(", volumes, ")")
      }
      names(volumes) <- volNames
      volumes <- gsub(":$", ":/", volumes)
    } else {
      stop("unsupported OS")
    }
    if (!is.null(exclude)) {
      volumes <- volumes[!names(volumes) %in% exclude]
    }
    volumes
  }
}

getSession <- function() {
  session <- shiny::getDefaultReactiveDomain()

  if (is.null(session)) {
    stop(paste(
      "could not find the Shiny session object. This usually happens when a",
      "shinyjs function is called from a context that wasn't set up by a Shiny session."
    ))
  }

  session
}
