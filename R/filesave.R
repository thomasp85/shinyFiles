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
#' server <- shinyServer(function(input, output, session) {
#'     shinyFileSave(input, 'save', session=session, roots=c(wd='.'))
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
#' @importFrom shiny observe invalidateLater
#' 
shinyFileSave <- function(input, id, updateFreq=2000, session, ...) {
    fileGet <- do.call('fileGetter', list(...))
    dirCreate <- do.call('dirCreator', list(...))
    currentDir <- list()
    lastDirCreate <- NULL
    
    return(observe({
        dir <- input[[paste0(id, '-modal')]]
        createDir <- input[[paste0(id, '-newDir')]]
        if(!identical(createDir, lastDirCreate)) {
            dirCreate(createDir$name, createDir$path, createDir$root)
            dir$path <- c(dir$path, createDir$name)
            lastDirCreate <<- createDir
        }
        if(is.null(dir) || is.na(dir)) {
            dir <- list(dir='')
        } else {
            dir <- list(dir=dir$path, root=dir$root)
        }
        dir$dir <- do.call(file.path, as.list(dir$dir))
        newDir <- do.call('fileGet', dir)
        if(!identical(currentDir, newDir) && newDir$exist) {
            currentDir <<- newDir
            session$sendCustomMessage('shinySave', list(id=id, dir=newDir))
        }
        invalidateLater(updateFreq, session)
    }))
}
#' @rdname shinyFiles-buttons
#' 
#' @importFrom htmltools tagList singleton tags
#' 
#' @export
#' 
shinySaveButton <- function(id, label, title, filetype, buttonType='default', class=NULL) {
    if(missing(filetype)) filetype <- NA
    filetype <- formatFiletype(filetype)
    
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
            class=paste(c('shinySave btn', paste0('btn-', buttonType), class), collapse=' '),
            'data-title'=title,
            'data-filetype'=filetype,
            as.character(label)
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
#' @importFrom RJSONIO toJSON
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
    if(is.null(selection)) return(data.frame(name=character(), type=character(), datapath=character()))
    
    currentRoots <- if(class(roots) == 'function') roots() else roots
    
    if (is.null(names(currentRoots))) stop('Roots must be a named vector or a function returning one')
    
    root <- currentRoots[selection$root]
    
    location <- do.call('file.path', as.list(selection$path))
    savefile <- file.path(root, location, selection$name)
    
    data.frame(name=selection$name, type=selection$type, datapath=savefile)
}