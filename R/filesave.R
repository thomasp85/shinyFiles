#' @include aaa.R
#' @include filechoose.R
#' @include dirchoose.R
#'
NULL

#' @rdname shinyFiles-observers
#'
#' @examples
#' \dontrun{
#' # File selections
#' ui <- shinyUI(bootstrapPage(
#'   shinySaveButton('save', 'Save', 'Save as...')
#' ))
#' server <- shinyServer(function(input, output) {
#'   shinyFileSave(input, 'save', roots=c(wd='.'))
#' })
#'
#' runApp(list(
#'   ui=ui,
#'   server=server
#' ))
#' }
#'
#' @importFrom shiny observe invalidateLater req observeEvent showNotification p
#' 
#' @export
#'
shinyFileSave <- function(
  input, id, updateFreq = 0, session = getSession(),
  defaultPath = "", defaultRoot = NULL, allowDirCreate = TRUE, ...
) {
  fileGet <- do.call(fileGetter, list(...))
  dirCreate <- do.call(dirCreator, list(...))
  currentDir <- list()
  lastDirCreate <- NULL
  clientId <- session$ns(id)

  sendDirectoryData <- function(message) {
    req(input[[id]])
    dir <- input[[paste0(id, "-modal")]]
    createDir <- input[[paste0(id, "-newDir")]]
    
    # Show a notification if a user is trying to create a 
    # new directory when that option has been disabled 
    if (!identical(createDir, lastDirCreate)) {
      if (allowDirCreate) {
        dirCreate(createDir$name, createDir$path, createDir$root)
        lastDirCreate <<- createDir
      } else {
        shiny::showNotification(shiny::p('Creating directories has been disabled.'), type = 'error')
        lastDirCreate <<- createDir
      }
    }
    
    if (is.null(dir) || is.na(dir)) {
      dir <- list(dir = defaultPath, root = defaultRoot)
    } else {
      dir <- list(dir = dir$path, root = dir$root)
    }
    dir$dir <- paste0(dir$dir, collapse = "/")
    newDir <- do.call(fileGet, dir)
    if (isTRUE(newDir$exist)) {
      currentDir <<- newDir
      session$sendCustomMessage(message, list(id = clientId, dir = newDir))
    }else{
      #first, back up a directory and try again; maybe the user is trying to save as a new filename
      savedDir = dir$dir
      selectedFile = sub(".*/(.*)$","\\1",dir$dir)
      #shorten the directory (include the slash at the end to make sure we don't look for a non-directory)
      dir$dir = sub("(.*/).*$","\\1",dir$dir)
      newDir <- do.call(fileGet, dir)
      if (isTRUE(newDir$exist)) { #backing up once, we find a valid directory
        newDir$selectedFile <- selectedFile
        currentDir <<- newDir
        session$sendCustomMessage(message, list(id = clientId, dir = newDir))
      }else{
        #even backing up, the directory is not valid
        currentDir$exist = FALSE
        session$sendCustomMessage(message, list(id = clientId, dir = currentDir))
      }
    }
    if (updateFreq > 0) invalidateLater(updateFreq, session)
  }

  observe({
    sendDirectoryData("shinySave")
  })

  observeEvent(input[[paste0(id, "-refresh")]], {
    if (!is.null(input[[paste0(id, "-refresh")]])) {
      sendDirectoryData("shinySave-refresh")
    }
  })
}
#' @rdname shinyFiles-buttons
#' @param filename A predefined filename to be filed in. Can be modified by the
#' user during saving.
#' @importFrom htmltools tagList singleton tags
#' @importFrom shiny restoreInput
#'
#' @export
#'
shinySaveButton <- function(
  id, label, title, filename="", filetype,  buttonType="default", 
  class=NULL, icon=NULL, style=NULL, viewtype="detail", ...
) {
  if (missing(filetype)) filetype <- NA
  filetype <- formatFiletype(filetype)
  viewtype <- if (length(viewtype) > 0 && viewtype %in% c("detail", "list", "icon")) viewtype else "detail"

  value <- restoreInput(id = id, default = NULL)
  tagList(
    singleton(tags$head(
      tags$script(src = "sF/shinyFiles.js"),
      tags$link(
        rel = "stylesheet",
        type = "text/css",
        href = "sF/styles.css"
      ),
      tags$link(
        rel = "stylesheet",
        type = "text/css",
        href = "sF/fileIcons.css"
      )
    )),
    tags$button(
      id = id,
      type = "button",
      class = paste(c("shinySave btn", paste0("btn-", buttonType), class, "action-button"), collapse = " "),
      style = style,
      "data-title" = title,
      "data-filetype" = filetype,
      "data-filename" = filename,
      "data-val" = value,
      "data-view" = paste0("sF-btn-", viewtype),
      list(icon, label),
      ...
    )
  )
}
#' @rdname shinyFiles-buttons
#'
#' @importFrom htmltools tagList singleton tags
#' @importFrom shiny restoreInput
#'
#' @export
#'
shinySaveLink <- function(
  id, label, title, filename="", filetype, 
  class=NULL, icon=NULL, style=NULL, viewtype="detail", ...
) {
  if (missing(filetype)) filetype <- NA
  filetype <- formatFiletype(filetype)
  viewtype <- if (length(viewtype) > 0 && viewtype %in% c("detail", "list", "icon")) viewtype else "detail"

  value <- restoreInput(id = id, default = NULL)
  tagList(
    singleton(tags$head(
      tags$script(src = "sF/shinyFiles.js"),
      tags$link(
        rel = "stylesheet",
        type = "text/css",
        href = "sF/styles.css"
      ),
      tags$link(
        rel = "stylesheet",
        type = "text/css",
        href = "sF/fileIcons.css"
      )
    )),
    tags$a(
      id = id,
      type = "button",
      class = paste(c("shinySave", class, "action-button"), collapse = " "),
      style = style,
      "data-title" = title,
      "data-filetype" = filetype,
      "data-filename" = filename,
      "data-val" = value,
      "data-view" = paste0("sF-btn-", viewtype),
      list(icon, label),
      ...
    )
  )
}

#' Formats the value of the filetype argument
#'
#' This function is intended to format the filetype argument of
#' [shinySaveButton()] into a json string representation, so that it
#' can be attached to the button.
#'
#' @param filetype A named list of file extensions or NULL or NA
#'
#' @return A string describing the input value in json format
#'
#' @importFrom jsonlite toJSON
#'
formatFiletype <- function(filetype) {
  if (!is.na(filetype) && !is.null(filetype)) {
    filetype <- lapply(1:length(filetype), function(i) {
      list(name = names(filetype)[i], ext = I(filetype[[i]]))
    })
  }
  toJSON(filetype)
}
#' @rdname shinyFiles-parsers
#'
#' @importFrom fs path path_file
#' @importFrom tibble tibble
#' 
#' @export
#'
parseSavePath <- function(roots, selection) {
  if (all(is.null(selection))) {
    return(tibble(
      name = character(), type = character(),
      datapath = character(), stringsAsFactors = FALSE
    ))
  }

  currentRoots <- if (inherits(roots, "function")) roots() else roots
  if (all(is.null(names(currentRoots)))) stop("Roots must be a named vector or a function returning one")

  if (all(is.integer(selection))) {
    tibble(name = character(0), type = character(0), datapath = character(0), stringsAsFactors = FALSE)
  } else {
    root <- currentRoots[selection$root]
    savefile <- path(root, paste0(c(selection$path, selection$name), collapse = "/"))
    type <- selection$type
    type <- if (length(type) == 0) "" else unlist(type)
    tibble(name = path_file(savefile), type = type, datapath = savefile, stringsAsFactors = FALSE)
  }
}
