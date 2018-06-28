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
#'     shinySaveButton('save', 'Save', 'Save as...')
#' ))
#' server <- shinyServer(function(input, output) {
#'     shinyFileSave(input, 'save', roots=c(wd='.'))
#' })
#' 
#' runApp(list(
#'     ui=ui,
#'     server=server
#' ))
#' }
#' 
#' @export
#' 
#' @importFrom shiny observe invalidateLater req
#' 
shinyFileSave <- function(input, id, updateFreq = 0, session=getSession(),
                          defaultPath='', defaultRoot=NULL, ...) {
    fileGet <- do.call('fileGetter', list(...))
    dirCreate <- do.call('dirCreator', list(...))
    currentDir <- list()
    lastDirCreate <- NULL
    clientId = session$ns(id)
    
    return(observe({
        req(input[[id]])
        dir <- input[[paste0(id, '-modal')]]
        createDir <- input[[paste0(id, '-newDir')]]
        if(!identical(createDir, lastDirCreate)) {
            dirCreate(createDir$name, createDir$path, createDir$root)
            dir$path <- c(dir$path, createDir$name)
            lastDirCreate <<- createDir
        }
        if(is.null(dir) || is.na(dir)) {
            dir <- list(dir=defaultPath, root=defaultRoot)
        } else {
            dir <- list(dir=dir$path, root=dir$root)
        }
        dir$dir <- do.call(file.path, as.list(dir$dir))
        newDir <- do.call('fileGet', dir)
        if(newDir$exist) {
            currentDir <<- newDir
            session$sendCustomMessage('shinySave', list(id=clientId, dir=newDir))
        } else if (isTRUE(nchar(createDir$name) > 0)) {
            dir <- list(dir=createDir$name, root=dir$root)
            currentDir <<- do.call('fileGet', dir)
            session$sendCustomMessage('shinySave', list(id=clientId, dir=currentDir))
        }
        if (updateFreq > 0) invalidateLater(updateFreq, session)
    }))
}
#' @rdname shinyFiles-buttons
#' 
#' @importFrom htmltools tagList singleton tags
#' @importFrom shiny restoreInput
#' 
#' @export
#' 
shinySaveButton <- function(id, label, title, filetype, buttonType='default', class=NULL, icon=NULL) {
    if(missing(filetype)) filetype <- NA
    filetype <- formatFiletype(filetype)
    
    value <- restoreInput(id = id, default = NULL)
    tagList(
        singleton(tags$head(
            tags$script(src='sF/shinyFiles.js'),
            tags$link(
                rel='stylesheet',
                type='text/css',
                href='sF/styles.css'
            ),
            tags$link(
                rel='stylesheet',
                type='text/css',
                href='sF/fileIcons.css'
            )
        )),
        tags$button(
            id=id,
            type='button',
            class=paste(c('shinySave btn', paste0('btn-', buttonType), class, 'action-button'), collapse=' '),
            'data-title'=title,
            'data-filetype'=filetype,
            'data-val' = value,
            list(icon, label)
        )
    )
}
#' Formats the value of the filetype argument
#' 
#' This function is intended to format the filetype argument of 
#' \code{\link{shinySaveButton}} into a json string representation, so that it
#' can be attached to the button.
#' 
#' @param filetype A named list of file extensions or NULL or NA
#' 
#' @return A string describing the input value in json format
#' 
#' @importFrom jsonlite toJSON
#' 
formatFiletype <- function(filetype) {
    if(!is.na(filetype) && !is.null(filetype)) {
        filetype <- lapply(1:length(filetype), function(i) {
            list(name=names(filetype)[i], ext=I(filetype[[i]]))
        })
    }
    toJSON(filetype)
}
#' @rdname shinyFiles-parsers
#' 
#' @export
#' 
parseSavePath <- function(roots, selection) {
    if(is.null(selection)) return(data.frame(name=character(), type=character(),
                                             datapath=character(), stringsAsFactors = FALSE))
    
    currentRoots <- if(class(roots) == 'function') roots() else roots
    
    if (is.null(names(currentRoots))) stop('Roots must be a named vector or a function returning one')
    
    if (is.integer(selection)) {
      data.frame(name = character(0), type = character(0), datapath = character(0), stringsAsFactors = FALSE)
    } else {
      root <- currentRoots[selection$root]
      location <- do.call('file.path', as.list(selection$path))
      savefile <- file.path(root, location, selection$name)
      savefile <- gsub(pattern='//*', '/', savefile, perl=TRUE)
      type <- selection$type
      type <- if (is.null(type)) "" else unlist(type)
      data.frame(name = selection$name, type = type, datapath = savefile, stringsAsFactors = FALSE)
    }
}
