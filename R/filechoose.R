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
            fileInfo <- fileInfo[tolower(fileInfo$extension) %in% tolower(filetypes) | fileInfo$isdir,]
        }
        rownames(fileInfo) <- NULL
        breadcrumps <- strsplit(dir, .Platform$file.sep)[[1]]
        list(
            files=fileInfo[, c('filename', 'extension', 'isdir', 'size', 'mtime', 'ctime', 'atime')],
            breadcrumps=I(c('', breadcrumps[breadcrumps != ''])),
            roots=names(currentRoots),
            root=root
            )
    }
}

#' Creates a reactive expression that updates the filesystem view
#' 
#' This function sets up the required connection to the client in order for the 
#' user to navigate the filesystem. For this to work a matching button should be
#' present in the html, either by using \code{shinyFilesButton()} or adding it
#' manually. See \code{\link{shinyFilesButton}} for more information on this.
#' 
#' Restrictions on the access rights of the client can be given in several ways.
#' The root parameter specifies the starting position for the filesystem as 
#' presented to the client. This means that the client can only navigate in
#' subdirectories of the root. Paths passed of to the \code{restrictions} 
#' parameter will not show up in the client view, and it is impossible to 
#' navigate into these subdirectories. The \code{filetypes} parameter takes a 
#' vector of of file extensions to filter the output on, so that the client is 
#' only presented with these filetypes. The \code{hidden} parameter toggles 
#' whether hidden files should be visible or not.
#' 
#' @param input The input object of the \code{shinyServer()} call (usaully 
#' \code{input})
#' 
#' @param inputId The same ID as used in the matching call to 
#' \code{shinyFilesButton} or as the id attribute of the button, in case of a
#' manually defined html.
#' 
#' @param updateFreq The time in milliseconds between file system lookups. This
#' determines the responsiveness to changes in the filesystem (e.g. addition of
#' files or drives)
#' 
#' @param session The session object of the shinyServer call (usually 
#' 'session'). Used to terminate file system lookups when the client leaves.
#' 
#' @param ... Arguments to be passed on to \code{\link{fileGetter}}
#' 
#' @return A reactive expression that should be assigned to the output object of
#' the \code{shinyServer()} call. The output name it should be assigned to have
#' to match the provided \code{inputId}
#' 
#' @examples
#' \dontrun{
#' ui <- shinyUI(bootstrapPage(
#'     shinyFilesButton('files', 'File select', 'Please select a file', FALSE)
#' ))
#' server <- shinyServer(function(input, output, session) {
#'     output$files <- shinyFileChoose(input, 'files', session=session, 
#'                                     roots=c(wd='.'), filetypes=c('', '.txt'))
#' })
#' 
#' runApp(list(
#'     ui=ui,
#'     server=server
#' ))
#' }
#' 
#' @family shinyFiles
#' 
#' @importFrom shiny reactive invalidateLater
#' 
#' @export
#' 
shinyFileChoose <- function(input, inputId, updateFreq=2000, session=NULL, ...) {
    fileGet <- do.call('fileGetter', list(...))
    
    return(reactive({
        dir <- input[[paste0(inputId, '-modal')]]
        if(is.null(dir) || is.na(dir)) {
            dir <- list(dir='')
        } else {
            dir <- list(dir=dir$path, root=dir$root)
        }
        dir$dir <- do.call(file.path, as.list(dir$dir))
        invalidateLater(updateFreq, session)
        do.call('fileGet', dir)
    }))
}

#' Create a button to summon the file system navigator
#' 
#' This function adds the required html markup for the client to access the file
#' system. The end result will be the appearance of a button on the webpage that
#' summons the file system navigator dialog box. The last position in the file
#' system is automatically remembered between instances, but not shared between 
#' several shinyFiles buttons. After adding a shinyFiles button the selected 
#' file(s) will be available in \code{input$inputId} (providing \code{input} is 
#' the name of the input object in the \code{shinyServer()} call). The file 
#' names should be parsed with \code{\link{parseFilePaths}} before usage though,
#' to make them compliant with the \code{\link[shiny]{fileInput}} function.
#' 
#' @details
#' When a user selects one or several files the corresponding input variable is
#' set to a list containing a character vector for each file. The character 
#' vectors gives the traversal route from the root to the selected file(s). The 
#' reason it does not give a path as a string is that the client has no 
#' knowledge of the file system on the server and can therefore not ensure 
#' proper formatting. As described above the input variable should be wrapped in
#' a call to \code{\link{parseFilePaths}} for a more beautiful output.
#' 
#' For users wanting to design their html markup manually it is very easy to add
#' a shinyFiles button. The only markup required is:
#' 
#' \code{<button id="inputId" type="button" class="shinyFiles btn" data-title="title" data-selecttype="single"|"multiple">label</button>}
#' 
#' where the id tag matches the inputId parameter, the data-title tag matches 
#' the title parameter, the data-selecttype is either "single" or "multiple" (
#' the non-logical form of the multiple parameter) and the internal textnode 
#' mathces the label parameter.
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
#' .sF-file .sF-file-icon .yourFileExtension{
#' content: url(path/to/16x16/pixel/png);
#' }
#' .sF-fileList.sF-icons .sF-file .sF-file-icon .yourFileExtension{
#' content: url(path/to/32x32/pixel/png);
#' }
#' 
#' If no large version is specified the small version gets upscaled.
#' 
#' @param inputId Input variable to assign the control's value to
#' 
#' @param label The text that should appear on the button
#' 
#' @param title The heading of the dialog box that appears when the button is 
#' pressed
#' 
#' @param multiple A logical indicating whether or not it should be possible to 
#' select multiple files
#' 
#' @family shinyFiles
#' 
#' @references The file icons used in the file system navigator is taken from
#' FatCows Farm-Fresh Web Icons (\url{http://www.fatcow.com/free-icons})
#' 
#' @importFrom shiny tagList singleton tags
#' 
#' @export
#' 
shinyFilesButton <- function(inputId, label, title, multiple) {
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
            id=inputId,
            type='button',
            class='shinyFiles btn',
            'data-title'=title,
            'data-selecttype'=ifelse(multiple, 'mulitple', 'single'),
            as.character(label)
            )
        )
}

#' Convert the output of a file choice to a data frame
#' 
#' This function takes the value of a shinyFiles button input variable and 
#' converts it to a data frame of the same format as that provided by 
#' \code{\link[shiny]{fileInput}}. The only caveat is that the MIME type cannot 
#' be inferred so this will always be an empty string.
#' 
#' The use of \code{parseFilePaths} makes it easy to substitute fileInput and 
#' shinyFiles in your code as code that relies on the values of a file selection
#' doesn't have to change.
#' 
#' @param roots The path to the root as specified in the \code{shinyFileChoose()}
#' call in \code{shinyServer()}
#' 
#' @param files The corresponding input variable to be parsed
#' 
#' @return A data frame mathcing the format of \code{link[shiny]{fileInput}}
#' 
#' @examples
#' \dontrun{
#' ui <- shinyUI(bootstrapPage(
#'     shinyFilesButton('files', 'File select', 'Please select a file', FALSE)
#'     verbatimTextOutput('filepaths')
#' ))
#' server <- shinyServer(function(input, output) {
#'     output$files <- shinyFileChoose(input, 'files', roots=c(wd='.'), 
#'                                     filetypes=c('', '.txt'))
#'     output$filepaths <- renderText({parseFilePaths('.', input$files)})
#' })
#' 
#' runApp(list(
#'     ui=ui,
#'     server=server
#' ))
#' }
#' 
#' @family shinyFiles
#' 
#' @export
#' 
parseFilePaths <- function(roots, files) {
    if (is.null(files) || is.na(files)) return(data.frame(name=character(0), size=numeric(0), type=character(0), datapath=character(0)))
    files <- sapply(files$files, function(x) {file.path(roots[files$root], do.call('file.path', x))})
    files <- gsub(pattern='//*', '/', files, perl=TRUE)
    
    data.frame(name=basename(files), size=file.info(files)$size, type='', datapath=files)
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