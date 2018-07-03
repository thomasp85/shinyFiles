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
#' @export
#'
#' @importFrom shiny observe invalidateLater req
#'
shinyFileSave <- function(input, id, updateFreq=0, session=getSession(),
                          defaultPath="", defaultRoot=NULL, ...) {
  fileGet <- do.call(fileGetter, list(...))
  dirCreate <- do.call(dirCreator, list(...))
  currentDir <- list()
  lastDirCreate <- NULL
  clientId <- session$ns(id)

  observe({
    req(input[[id]])
    dir <- input[[paste0(id, "-modal")]]
    createDir <- input[[paste0(id, "-newDir")]]
    if (!identical(createDir, lastDirCreate)) {
      dirCreate(createDir$name, createDir$path, createDir$root)
      lastDirCreate <<- createDir
    }
    if (is.null(dir) || is.na(dir)) {
      dir <- list(dir = defaultPath, root = defaultRoot)
    } else {
      dir <- list(dir = dir$path, root = dir$root)
    }
    dir$dir <- do.call(file.path, as.list(dir$dir))
    newDir <- do.call(fileGet, dir)
    if (newDir$exist) {
      currentDir <<- newDir
      session$sendCustomMessage("shinySave", list(id = clientId, dir = newDir))
    }
    if (updateFreq > 0) invalidateLater(updateFreq, session)
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
shinySaveButton <- function(id, label, title, filename="", filetype, 
                            buttonType="default", class=NULL, icon=NULL) {
  if (missing(filetype)) filetype <- NA
  filetype <- formatFiletype(filetype)

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
      "data-title" = title,
      "data-filetype" = filetype,
      "data-filename" = filename,
      "data-val" = value,
      list(icon, label)
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
shinySaveLink <- function(id, label, title, filename="", filetype, class=NULL, icon=NULL) {
  if (missing(filetype)) filetype <- NA
  filetype <- formatFiletype(filetype)

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
      "data-title" = title,
      "data-filetype" = filetype,
      "data-filename" = filename,
      "data-val" = value,
      list(icon, label)
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
#' @export
#'
parseSavePath <- function(roots, selection) {
  if (is.null(selection)) {
    return(data.frame(
      name = character(), type = character(),
      datapath = character(), stringsAsFactors = FALSE
    ))
  }

  currentRoots <- if (class(roots) == "function") roots() else roots

  if (is.null(names(currentRoots))) stop("Roots must be a named vector or a function returning one")

  if (is.integer(selection)) {
    data.frame(name = character(0), type = character(0), datapath = character(0), stringsAsFactors = FALSE)
  } else {
    root <- currentRoots[selection$root]
    savefile <- do.call(file.path, as.list(dropEmpty(c(root, selection$path, selection$name))))
    type <- selection$type
    type <- if (length(type) == 0) "" else unlist(type)
    data.frame(name = selection$name, type = type, datapath = savefile, stringsAsFactors = FALSE)
  }
}
