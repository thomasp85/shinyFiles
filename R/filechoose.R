#' @include aaa.R
NULL

#' Create a function that returns fileinfo according to the given restrictions
#' 
#' This functions returns a new function that can generate file information to 
#' be send to a shiny app based on a path relative to the given root. The 
#' function is secure in the sense that it prevents access to files outside of
#' the given root directory as well as to subdirectories matching the ones given
#' in restrictions. Furthermore can the output be filtered to only contain 
#' certain filetypes using the filter parameter and hidden files can be toggled
#' with the hidden parameter.
#' 
#' @param roots A named vector of absolute filepaths or a function returning a 
#' named vector of absolute filepaths (the latter is useful if the volumes
#' should adapt to changes in the filesystem).
#' 
#' @param restrictions A vector of directories within the root that should be
#' filtered out of the results
#' 
#' @param filetypes A character vector of file extensions (without dot in front 
#' i.e. 'txt' not '.txt') to include in the output. Use the empty string to 
#' include files with no extension. If not set all file types will be included
#' 
#' @param hidden A logical value specifying whether hidden files should be 
#' returned or not
#' 
#' @return A function taking a single path relative to the specified root, and
#' returns a list of files to be passed on to shiny
#' 
#' @importFrom tools file_ext
#' 
fileGetter <- function(roots, restrictions, filetypes, hidden=FALSE) {
    if (missing(filetypes)) filetypes <- NULL
    if (missing(restrictions)) restrictions <- NULL
    
    function(dir, root) {
        currentRoots <- if(class(roots) == 'function') roots() else roots
        
        if (is.null(names(currentRoots))) stop('Roots must be a named vector or a function returning one')
        if (missing(root)) root <- names(currentRoots)[1]
        
        fulldir <- file.path(currentRoots[root], dir)
        writable <- as.logical(file.access(fulldir, 2) == 0)
        files <- list.files(fulldir, all.files=hidden, full.names=TRUE, no..=TRUE)
        files <- gsub(pattern='//*', '/', files, perl=TRUE)
        if (!is.null(restrictions) && length(files) != 0) {
            if (length(files) == 1) {
                keep <- !any(sapply(restrictions, function(x) {grepl(x, files, fixed=T)}))
            } else {
                keep <- !apply(sapply(restrictions, function(x) {grepl(x, files, fixed=T)}), 1, any)
            }
            files <- files[keep]
        }
        fileInfo <- file.info(files)
        fileInfo$filename <- basename(files)
        fileInfo$extension <- tolower(file_ext(files))
        fileInfo$mtime <- format(fileInfo$mtime, format='%Y-%m-%d-%H-%M')
        fileInfo$ctime <- format(fileInfo$ctime, format='%Y-%m-%d-%H-%M')
        fileInfo$atime <- format(fileInfo$atime, format='%Y-%m-%d-%H-%M')
        if (!is.null(filetypes)) {
            matchedFiles <- tolower(fileInfo$extension) %in% tolower(filetypes) & fileInfo$extension != ''
            fileInfo$isdir[matchedFiles] <- FALSE
            fileInfo <- fileInfo[matchedFiles | fileInfo$isdir,]
        }
        rownames(fileInfo) <- NULL
        breadcrumps <- strsplit(dir, .Platform$file.sep)[[1]]
        list(
            files=fileInfo[, c('filename', 'extension', 'isdir', 'size', 'mtime', 'ctime', 'atime')],
            writable=writable,
            exist=file.exists(fulldir),
            breadcrumps=I(c('', breadcrumps[breadcrumps != ''])),
            roots=I(names(currentRoots)),
            root=root
            )
    }
}

#' Create a connection to the server side filesystem
#' 
#' These function sets up the required connection to the client in order for the 
#' user to navigate the filesystem. For this to work a matching button should be
#' present in the html, either by using one of the button generating functions 
#' or adding it manually. See \code{\link{shinyFiles-buttons}} for more details.
#' 
#' Restrictions on the access rights of the client can be given in several ways.
#' The root parameter specifies the starting position for the filesystem as 
#' presented to the client. This means that the client can only navigate in
#' subdirectories of the root. Paths passed of to the \code{restrictions} 
#' parameter will not show up in the client view, and it is impossible to 
#' navigate into these subdirectories. The \code{filetypes} parameter takes a 
#' vector of file extensions to filter the output on, so that the client is 
#' only presented with these filetypes. The \code{hidden} parameter toggles 
#' whether hidden files should be visible or not. Whenever a file or folder 
#' choice is made the resulting files/folder will be accessible in the input 
#' variable with the id given in the parameters. This value should probable be 
#' run through a call to one of the parser (\code{\link{shinyFiles-parsers}}) in 
#' order to get well formatted paths to work with.
#' 
#' @param input The input object of the \code{shinyServer()} call (usaully 
#' \code{input})
#' 
#' @param id The same ID as used in the matching call to 
#' \code{shinyFilesButton} or as the id attribute of the button, in case of a
#' manually defined html. This id will also define the id of the file choice in 
#' the input variable
#' 
#' @param updateFreq The time in milliseconds between file system lookups. This
#' determines the responsiveness to changes in the filesystem (e.g. addition of
#' files or drives)
#' 
#' @param session The session object of the shinyServer call (usually 
#' \code{session}).
#' 
#' @param ... Arguments to be passed on to \code{\link{fileGetter}} or 
#' \code{\link{dirGetter}}
#' 
#' @return A reactive observer that takes care of the server side logic of the 
#' filesystem connection.
#' 
#' @note The syntax for this version has changed with version 0.4.0. Prior to
#' that version the output of \code{shinyFileChoose()} should be assigned to the
#' output object. This is no longer the case and doing so will result in an 
#' error. In newer versions the function returns an observer which can be 
#' ignored for the most part, or assigned to a variable if there needs to be 
#' interactions with it later on.
#' 
#' @examples
#' \dontrun{
#' # File selections
#' ui <- shinyUI(bootstrapPage(
#'     shinyFilesButton('files', 'File select', 'Please select a file', FALSE)
#' ))
#' server <- shinyServer(function(input, output) {
#'     shinyFileChoose(input, 'files', roots=c(wd='.'), filetypes=c('', 'txt'))
#' })
#' 
#' runApp(list(
#'     ui=ui,
#'     server=server
#' ))
#' }
#' 
#' @rdname shinyFiles-observers
#' @name shinyFiles-observers
#' 
#' @family shinyFiles
#' 
#' @importFrom shiny observe invalidateLater
#' 
#' @export
#' 
shinyFileChoose <- function(input, id, updateFreq=2000, session = getSession(), ...) {
    fileGet <- do.call('fileGetter', list(...))
    currentDir <- list()
    
    return(observe({
        dir <- input[[paste0(id, '-modal')]]
        if(is.null(dir) || is.na(dir)) {
            dir <- list(dir='')
        } else {
            dir <- list(dir=dir$path, root=dir$root)
        }
        dir$dir <- do.call(file.path, as.list(dir$dir))
        newDir <- do.call('fileGet', dir)
        if(!identical(currentDir, newDir)) {
            currentDir <<- newDir
            session$sendCustomMessage('shinyFiles', list(id=id, dir=newDir))
        }
        invalidateLater(updateFreq, session)
    }))
}

#' Create a button to summon a shinyFiles dialog
#' 
#' This function adds the required html markup for the client to access the file
#' system. The end result will be the appearance of a button on the webpage that
#' summons one of the shinyFiles dialog boxes. The last position in the file
#' system is automatically remembered between instances, but not shared between 
#' several shinyFiles buttons. For a button to have any functionality it must
#' have a matching observer on the server side. shinyFilesButton() is matched 
#' with shinyFileChoose() and shinyDirButton with shinyDirChoose(). The id
#' argument of two matching calls must be the same. See 
#' \code{\link{shinyFiles-observers}} on how to handle client input on the 
#' server side.
#' 
#' @details
#' \strong{Selecting files}
#' 
#' When a user selects one or several files the corresponding input variable is
#' set to a list containing a character vector for each file. The character 
#' vectors gives the traversal route from the root to the selected file(s). The 
#' reason it does not give a path as a string is that the client has no 
#' knowledge of the file system on the server and can therefore not ensure 
#' proper formatting. The \code{\link{parseFilePaths}} function can be used on
#' the server to format the input variable into a format similar to that 
#' returned by \code{\link[shiny]{fileInput}}.
#' 
#' \strong{Selecting folders}
#' 
#' When a folder is selected it will also be available in its respective input
#' variable as a list giving the traversal route to the selected folder. To
#' properly format it, feed it into \code{\link{parseDirPath}} and a string with
#' the full folder path will be returned.
#' 
#' \strong{Creating files (saving)}
#' 
#' When a new filename is created it will become available in the respective 
#' input variable and can be formatted with \code{\link{parseSavePath}} into a 
#' data.frame reminiscent that returned by fileInput. There is no size column 
#' and the type is only present if the filetype argument is used in 
#' \code{shinySaveButton}. In that case it will be the name of the chosen type
#' (not the extension).
#' 
#' \strong{Manual markup}
#' 
#' For users wanting to design their html markup manually it is very easy to add
#' a shinyFiles button. The only markup required is:
#' 
#' \emph{shinyFilesButton}
#' 
#' \code{<button id="inputId" type="button" class="shinyFiles btn btn-default" data-title="title" data-selecttype="single"|"multiple">label</button>}
#' 
#' \emph{shinyDirButton}
#' 
#' \code{<button id="inputId" type="button" class="shinyDirectories btn-default" data-title="title">label</button>}
#' 
#' \emph{shinySaveButton}
#' 
#' \code{<button id="inputId" type="button" class="shinySave btn-default" data-title="title" data-filetype="[{name: 'type1', ext: ['txt']}, {name: 'type2', ext: ['exe', 'bat']}]">label</button>}
#' 
#' where the id tag matches the inputId parameter, the data-title tag matches 
#' the title parameter, the data-selecttype is either "single" or "multiple" 
#' (the non-logical form of the multiple parameter) and the internal textnode 
#' mathces the label parameter. The data-filetype tag is a bit more involved as
#' it is a json formatted array of objects with the properties 'name' and 'ext'.
#' 'name' gives the name of the filetype as a string and 'ext' the allowed 
#' extensions as an array of strings. The non-exported 
#' \code{\link{formatFiletype}} function can help convert from a named R list 
#' into the string representation. In the example above "btn-default" is used as
#' button styling, but this can be changed to any other Bootstrap style. 
#' 
#' Apart from this the html document should link to a script with the 
#' following path 'sF/shinyFiles.js' and a stylesheet with the following path 
#' 'sF/styles.css'.
#' 
#' The markup is bootstrap compliant so if the bootstrap css is used in the page
#' the look will fit right in. There is nothing that hinders the developer from
#' ignoring bootstrap altogether and designing the visuals themselves. The only 
#' caveat being that the glyphs used in the menu buttons are bundled with 
#' bootstrap. Use the css ::after pseudoclasses to add alternative content to 
#' these buttons. Additional filetype specific icons can be added with css using
#' the following style:
#' 
#' \preformatted{
#' .sF-file .sF-file-icon .yourFileExtension{
#'     content: url(path/to/16x16/pixel/png);
#' }
#' .sF-fileList.sF-icons .sF-file .sF-file-icon .yourFileExtension{
#'     content: url(path/to/32x32/pixel/png);
#' }
#' }
#' 
#' If no large version is specified the small version gets upscaled.
#' 
#' \strong{Client side events}
#' 
#' If the shiny app uses custom Javascript it is possible to react to selections
#' directly from the javascript. Once a selection has been made, the button will
#' fire of the event 'selection' and pass the selection data along with the 
#' event. To listen for this event you simple add:
#' 
#' \preformatted{
#' $(button).on('selection', function(event, path) {
#'     // Do something with the paths here
#' })
#' }
#' 
#' in the same way a 'cancel' event is fired when a user dismisses a selection 
#' box. In that case, no path is passed on.
#' 
#' Outside events the current selection is available as an abject binded to the
#' button and can be accessed at any time:
#' 
#' \preformatted{
#' // For a shinyFilesButton
#' $(button).data('files')
#' 
#' // For a shinyDirButton
#' $(button).data('directory')
#' 
#' // For a shinySaveButton
#' $(button).data('file')
#' }
#' 
#' @param id The id matching the \code{\link{shinyFileChoose}}
#' 
#' @param label The text that should appear on the button
#' 
#' @param title The heading of the dialog box that appears when the button is 
#' pressed
#' 
#' @param multiple A logical indicating whether or not it should be possible to 
#' select multiple files
#' 
#' @param buttonType The Bootstrap button markup used to colour the button. 
#' Defaults to 'default' for a neutral appearance but can be changed for another
#' look. The value will be pasted with 'btn-' and added as class.
#' 
#' @param class Additional classes added to the button
#' 
#' @param filetype A named list of file extensions. The name of each element 
#' gives the name of the filetype and the content of the element the possible
#' extensions e.g. \code{list(picture=c('jpg', 'jpeg'))}. The first extension
#' will be used as default if it is not supplied by the user.
#' 
#' @return This function is called for its side effects
#' 
#' @rdname shinyFiles-buttons
#' @name shinyFiles-buttons
#' 
#' @family shinyFiles
#' 
#' @references The file icons used in the file system navigator is taken from
#' FatCows Farm-Fresh Web Icons (\url{http://www.fatcow.com/free-icons})
#' 
#' @importFrom htmltools tagList singleton tags
#' 
#' @export
#' 
shinyFilesButton <- function(id, label, title, multiple, buttonType='default', class=NULL) {
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
            class=paste(c('shinyFiles btn', paste0('btn-', buttonType), class), collapse=' '),
            'data-title'=title,
            'data-selecttype'=ifelse(multiple, 'multiple', 'single'),
            as.character(label)
            )
        )
}

#' Convert the output of a selection to platform specific path(s)
#' 
#' This function takes the value of a shinyFiles button input variable and 
#' converts it to be easier to work with on the server side. In the case of file
#' selections  and saving the input variable is converted to a data frame (using 
#' \code{parseFilePaths()} or \code{parseSavePath() respectively}) of the same 
#' format as that provided by \code{\link[shiny]{fileInput}}. The only caveat 
#' here is that the MIME type cannot be inferred in file selections so this will 
#' always be an empty string and new files doesn't have a size so this is left 
#' out with file saving. In the case of folder selection the input variable is 
#' converted to a string (using \code{parseDirPath()}) giving the absolute path 
#' to the selected folder.
#' 
#' The use of \code{parseFilePaths} makes it easy to substitute fileInput and 
#' shinyFiles in your code as code that relies on the values of a file selection
#' doesn't have to change.
#' 
#' @param roots The path to the root as specified in the \code{shinyFileChoose()}
#' call in \code{shinyServer()}
#' 
#' @param selection The corresponding input variable to be parsed
#' 
#' @return A data frame mathcing the format of \code{\link[shiny]{fileInput}}
#' 
#' @examples
#' \dontrun{
#' ui <- shinyUI(bootstrapPage(
#'     shinyFilesButton('files', 'File select', 'Please select a file', FALSE),
#'     verbatimTextOutput('rawInputValue'),
#'     verbatimTextOutput('filepaths')
#' ))
#' server <- shinyServer(function(input, output) {
#'     roots = c(wd='.')
#'     shinyFileChoose(input, 'files', roots=roots, filetypes=c('', 'txt'))
#'     output$rawInputValue <- renderPrint({str(input$files)})
#'     output$filepaths <- renderPrint({parseFilePaths(roots, input$files)})
#' })
#' 
#' runApp(list(
#'     ui=ui,
#'     server=server
#' ))
#' }
#' 
#' @rdname shinyFiles-parsers
#' @name shinyFiles-parsers
#' 
#' @family shinyFiles
#' 
#' @export
#' 
parseFilePaths <- function(roots, selection) {
    roots <- if(class(roots) == 'function') roots() else roots
    
    if (is.null(selection) || is.na(selection)) return(data.frame(name=character(0), size=numeric(0), type=character(0), datapath=character(0)))
    files <- sapply(selection$files, function(x) {file.path(roots[selection$root], do.call('file.path', x))})
    files <- gsub(pattern='//*', '/', files, perl=TRUE)
    
    data.frame(name=basename(files), size=file.info(files)$size, type='', datapath=files)
}