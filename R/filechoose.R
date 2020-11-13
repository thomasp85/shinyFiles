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
#' @param pattern A regular expression used to select files to show. See
#' \code{\link[base:grep]{base::grepl()}} for additional discussion on how to 
#' construct a regular expression (e.g., "log.*\\\\.txt")
#' 
#' @param hidden A logical value specifying whether hidden files should be
#' returned or not
#'
#' @return A function taking a single path relative to the specified root, and
#' returns a list of files to be passed on to shiny
#'
#' @importFrom tools file_ext
#' @importFrom fs path file_access file_exists dir_ls file_info path_file 
#'   path_ext path_join path_norm path_has_parent
#' @importFrom tibble as_tibble
#'
fileGetter <- function(roots, restrictions, filetypes, pattern, hidden = FALSE) {
  if (missing(filetypes)) {
    filetypes <- NULL
  } else if (is.function(filetypes)) {
    filetypes <- filetypes()
  }
  if (missing(restrictions)) restrictions <- NULL
  if (missing(pattern)) {
    pattern <- ""
  } else if (is.function(pattern)) {
    pattern <- pattern()
  }

  function(dir, root) {
    currentRoots <- if (inherits(roots, "function")) roots() else roots

    if (is.null(names(currentRoots))) stop("Roots must be a named vector or a function returning one")
    if (is.null(root)) root <- names(currentRoots)[1]
    
    fulldir <- path_join(c(currentRoots[root], dir))
    testdir <- try(path_norm(fulldir), silent = TRUE) 

    if (inherits(testdir, "try-error")) {
      fulldir <- path(currentRoots[root])
      dir <- ""
    } else {
      if (Sys.info()["sysname"] != "Windows") {
        testdir <- gsub("/{2,}", "/", testdir)
      }
      if (path_has_parent(testdir, currentRoots[root])) {
        fulldir <- testdir
      } else {
        fulldir <- path(currentRoots[root])
        dir <- ""
      }
    }
    
    selectedFile <- ""
    if(file.exists(fulldir) && !dir.exists(fulldir)){
      # dir is a normal file, not a directory
      # get the filename, and use it as the selectedFile
      selectedFile = sub(".*/(.*)$", "\\1", fulldir)
      # shorten the directory
      fulldir = sub("(.*)/.*$", "\\1", fulldir)
      # dir also needs shortened for breadcrumbs
      dir = sub("(.*)/.*$", "\\1", dir)
    }
    
    writable <- as.logical(file_access(fulldir, "write"))
    files <- suppressWarnings(dir_ls(fulldir, all = hidden, fail = FALSE))
  
    if (!is.null(restrictions) && length(files) != 0) {
      if (length(files) == 1) {
        keep <- !any(sapply(restrictions, function(x) {
          grepl(x, files, fixed = T)
        }))
      } else {
        keep <- !apply(sapply(restrictions, function(x) {
          grepl(x, files, fixed = T)
        }), 1, any)
      }
      files <- files[keep]
    }
    fileInfo <- suppressWarnings(file_info(files, fail = FALSE))
    fileInfo$filename <- path_file(files)
    fileInfo$extension <- tolower(path_ext(files))
    fileInfo$isdir <- dir.exists(files)
    fileInfo$mtime <- as.integer(fileInfo$modification_time) * 1000
    fileInfo$ctime <- as.integer(fileInfo$birth_time) * 1000
    fileInfo$atime <- as.integer(fileInfo$access_time) * 1000
    
    if (!is.null(filetypes)) {
      matchedFiles <- tolower(fileInfo$extension) %in% tolower(filetypes) & fileInfo$extension != ""
      fileInfo$isdir[matchedFiles] <- FALSE
      fileInfo <- fileInfo[matchedFiles | fileInfo$isdir, ]
    }
    
    if (nchar(pattern) > 0) {
      matchedFiles <- try(grepl(pattern, fileInfo$filename), silent = TRUE)
      if (!inherits(matchedFiles, "try-error")) {
        fileInfo <- fileInfo[matchedFiles | fileInfo$isdir, ]
      }
    }
    
    breadcrumps <- strsplit(dir, .Platform$file.sep)[[1]]
    
    list(
      files = as_tibble(fileInfo[, c("filename", "extension", "isdir", "size", "mtime", "ctime", "atime")]),
      writable = writable,
      exist = as.logical(file_exists(fulldir)),
      breadcrumps = I(c("", breadcrumps[breadcrumps != ""])),
      roots = I(names(currentRoots)),
      root = root,
      selectedFile = selectedFile
    )
  }
}

#' Create a connection to the server side filesystem
#'
#' These function sets up the required connection to the client in order for the
#' user to navigate the filesystem. For this to work a matching button should be
#' present in the html, either by using one of the button generating functions
#' or adding it manually. See [shinyFiles-buttons()] for more details.
#'
#' Restrictions on the access rights of the client can be given in several ways.
#' The root parameter specifies the starting position for the filesystem as
#' presented to the client. This means that the client can only navigate in
#' subdirectories of the root. Paths passed of to the `restrictions`
#' parameter will not show up in the client view, and it is impossible to
#' navigate into these subdirectories. The `filetypes` parameter takes a
#' vector of file extensions to filter the output on, so that the client is
#' only presented with these filetypes. The `hidden` parameter toggles
#' whether hidden files should be visible or not. Whenever a file or folder
#' choice is made the resulting files/folder will be accessible in the input
#' variable with the id given in the parameters. This value should probable be
#' run through a call to one of the parser ([shinyFiles-parsers()]) in
#' order to get well formatted paths to work with.
#'
#' @param input The input object of the `shinyServer()` call (usually
#' `input`)
#'
#' @param id The same ID as used in the matching call to
#' `shinyFilesButton` or as the id attribute of the button, in case of a
#' manually defined html. This id will also define the id of the file choice in
#' the input variable
#'
#' @param updateFreq The time in milliseconds between file system lookups. This
#' determines the responsiveness to changes in the filesystem (e.g. addition of
#' files or drives). For the default value (0) changes in the filesystem are
#' shown only when a shinyFiles button is clicked again
#'
#' @param session The session object of the shinyServer call (usually
#' `session`).
#'
#' @param defaultRoot The default root to use. For instance if
#' `roots = c('wd' = '.', 'home', '/home')` then `defaultRoot`
#' can be either `'wd'` or `'home'`.
#'
#' @param defaultPath The default relative path specified given the `defaultRoot`.
#' 
#' @param allowDirCreate Logical that indicates if creating new directories by the user is allowed.
#'
#' @param ... Arguments to be passed on to [fileGetter()] or [dirGetter()].
#'
#' @return A reactive observer that takes care of the server side logic of the
#' filesystem connection.
#'
#' @note The syntax for this version has changed with version 0.4.0. Prior to
#' that version the output of `shinyFileChoose()` should be assigned to the
#' output object. This is no longer the case and doing so will result in an
#' error. In newer versions the function returns an observer which can be
#' ignored for the most part, or assigned to a variable if there needs to be
#' interactions with it later on.
#'
#' @examples
#' \dontrun{
#' # File selections
#' ui <- shinyUI(bootstrapPage(
#'   shinyFilesButton('files', 'File select', 'Please select a file', FALSE)
#' ))
#' server <- shinyServer(function(input, output) {
#'   shinyFileChoose(input, 'files', roots=c(wd='.'), filetypes=c('', 'txt'),
#'                   defaultPath='', defaultRoot='wd')
#' })
#'
#' runApp(list(
#'   ui=ui,
#'   server=server
#' ))
#' }
#'
#' @rdname shinyFiles-observers
#' @name shinyFiles-observers
#'
#' @family shinyFiles
#'
#' @importFrom shiny observe invalidateLater req observeEvent
#' @importFrom fs path 
#'
#' @export
#'
shinyFileChoose <- function(input, id, updateFreq = 0, session = getSession(),
                            defaultRoot=NULL, defaultPath="", ...) {
  currentDir <- list()
  clientId <- session$ns(id)

  sendDirectoryData <- function(message) {
    req(input[[id]])
    dir <- input[[paste0(id, "-modal")]]
    if (is.null(dir) || is.na(dir)) {
      dir <- list(dir = defaultPath, root = defaultRoot)
    } else {
      dir <- list(dir = dir$path, root = dir$root)
    }
    dir$dir <- paste0(dir$dir, collapse = "/")
    ## allows reactive links (e.g., for filetypes)
    fileGet <- do.call(fileGetter, list(...))
    newDir <- do.call(fileGet, dir)
    currentDir <<- newDir
    session$sendCustomMessage(message, list(id = clientId, dir = newDir))
    if (updateFreq > 0) invalidateLater(updateFreq, session)
  }

  observe({
    sendDirectoryData("shinyFiles")
  })

  observeEvent(input[[paste0(id, "-refresh")]], {
    if (!is.null(input[[paste0(id, "-refresh")]])) {
      sendDirectoryData("shinyFiles-refresh")
    }
  })
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
#' [shinyFiles-observers()] on how to handle client input on the
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
#' proper formatting. The [parseFilePaths()] function can be used on
#' the server to format the input variable into a format similar to that
#' returned by [shiny::fileInput()].
#'
#' \strong{Selecting folders}
#'
#' When a folder is selected it will also be available in its respective input
#' variable as a list giving the traversal route to the selected folder. To
#' properly format it, feed it into [parseDirPath()] and a string with
#' the full folder path will be returned.
#'
#' \strong{Creating files (saving)}
#'
#' When a new filename is created it will become available in the respective
#' input variable and can be formatted with [parseSavePath()] into a
#' data.frame reminiscent that returned by fileInput. There is no size column
#' and the type is only present if the filetype argument is used in
#' `shinySaveButton`. In that case it will be the name of the chosen type
#' (not the extension).
#'
#' \strong{Manual markup}
#'
#' For users wanting to design their html markup manually it is very easy to add
#' a shinyFiles button. The only markup required is:
#'
#' *shinyFilesButton*
#'
#' `<button id="inputId" type="button" class="shinyFiles btn btn-default" data-title="title" data-selecttype="single"|"multiple">label</button>`
#'
#' *shinyDirButton*
#'
#' `<button id="inputId" type="button" class="shinyDirectories btn-default" data-title="title">label</button>`
#'
#' *shinySaveButton*
#'
#' \code{<button id="inputId" type="button" class="shinySave btn-default" data-title="title" data-filetype="[{name: 'type1', ext: ['txt']}, {name: 'type2', ext: ['exe', 'bat']}]">label</button>}
#'
#' where the id tag matches the inputId parameter, the data-title tag matches
#' the title parameter, the data-selecttype is either "single" or "multiple"
#' (the non-logical form of the multiple parameter) and the internal textnode
#' matches the label parameter. The data-filetype tag is a bit more involved as
#' it is a json formatted array of objects with the properties 'name' and 'ext'.
#' 'name' gives the name of the filetype as a string and 'ext' the allowed
#' extensions as an array of strings. The non-exported
#' [formatFiletype()] function can help convert from a named R list
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
#'   content: url(path/to/32x32/pixel/png);
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
#'   // Do something with the paths here
#' })
#' }
#'
#' in the same way a 'cancel' event is fired when a user dismisses a selection
#' box. In that case, no path is passed on.
#'
#' Outside events the current selection is available as an object bound to the
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
#' @param id The id matching the [shinyFileChoose()]
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
#' @param icon An optional \href{https://shiny.rstudio.com/reference/shiny/latest/icon.html}{icon} to appear on the button.
#' 
#' @param style Additional styling added to the button (e.g., "margin-top: 25px;")
#' 
#' @param viewtype View type to use in the file browser. One of "detail" (default), "list", or "icon"
#'
#' @param filetype A named list of file extensions. The name of each element
#' gives the name of the filetype and the content of the element the possible
#' extensions e.g. `list(picture=c('jpg', 'jpeg'))`. The first extension
#' will be used as default if it is not supplied by the user.
#' 
#' @param ... Named attributes to be applied to the button or link (e.g., 'onclick')
#'
#' @return This function is called for its side effects
#'
#' @rdname shinyFiles-buttons
#' @name shinyFiles-buttons
#'
#' @family shinyFiles
#'
#' @references The file icons used in the file system navigator is taken from
#' FatCows Farm-Fresh Web Icons (<https://www.fatcow.com/free-icons>)
#'
#' @importFrom htmltools tagList singleton tags
#' @importFrom shiny restoreInput
#'
#' @export
#'
shinyFilesButton <- function(
  id, label, title, multiple, buttonType="default", 
  class=NULL, icon=NULL, style=NULL, viewtype="detail", ...
) {
  value <- restoreInput(id = id, default = NULL)
  viewtype <- if (length(viewtype) > 0 && viewtype %in% c("detail", "list", "icon")) viewtype else "detail"
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
      class = paste(c("shinyFiles btn", paste0("btn-", buttonType), class, "action-button"), collapse = " "),
      style = style,
      "data-title" = title,
      "data-selecttype" = ifelse(multiple, "multiple", "single"),
      "data-val" = value,
      "data-view" = paste0("sF-btn-", viewtype),
      list(icon, label),
      ...
    )
  )
}

#' @rdname shinyFiles-buttons
#' @name shinyFiles-buttons
#' @importFrom htmltools tagList singleton tags
#' @importFrom shiny restoreInput
#'
#' @export
#'
shinyFilesLink <- function(
  id, label, title, multiple, class=NULL, icon=NULL, style=NULL, 
  viewtype="detail", ...
) {
  value <- restoreInput(id = id, default = NULL)
  viewtype <- if (length(viewtype) > 0 && viewtype %in% c("detail", "list", "icon")) viewtype else "detail"
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
      class = paste(c("shinyFiles", class, "action-button"), collapse = " "),
      style = style,
      "data-title" = title,
      "data-selecttype" = ifelse(multiple, "multiple", "single"),
      "data-val" = value,
      "data-view" = paste0("sF-btn-", viewtype),
      list(icon, label),
      ...
    )
  )
}


#' Convert the output of a selection to platform specific path(s)
#'
#' This function takes the value of a shinyFiles button input variable and
#' converts it to be easier to work with on the server side. In the case of file
#' selections  and saving the input variable is converted to a data frame (using
#' `parseFilePaths()` or `parseSavePath() respectively`) of the same
#' format as that provided by [shiny::fileInput()]. The only caveat
#' here is that the MIME type cannot be inferred in file selections so this will
#' always be an empty string and new files doesn't have a size so this is left
#' out with file saving. In the case of folder selection the input variable is
#' converted to a string (using `parseDirPath()`) giving the absolute path
#' to the selected folder.
#'
#' The use of `parseFilePaths` makes it easy to substitute fileInput and
#' shinyFiles in your code as code that relies on the values of a file selection
#' doesn't have to change.
#'
#' @param roots The path to the root as specified in the `shinyFileChoose()`
#' call in `shinyServer()`
#'
#' @param selection The corresponding input variable to be parsed
#'
#' @return A data frame matching the format of [shiny::fileInput()]
#'
#' @examples
#' \dontrun{
#' ui <- shinyUI(bootstrapPage(
#'   shinyFilesButton('files', 'File select', 'Please select a file', FALSE),
#'   verbatimTextOutput('rawInputValue'),
#'   verbatimTextOutput('filepaths')
#' ))
#' server <- shinyServer(function(input, output) {
#'   roots = c(wd='.')
#'   shinyFileChoose(input, 'files', roots=roots, filetypes=c('', 'txt'))
#'   output$rawInputValue <- renderPrint({str(input$files)})
#'   output$filepaths <- renderPrint({parseFilePaths(roots, input$files)})
#' })
#'
#' runApp(list(
#'   ui=ui,
#'   server=server
#' ))
#' }
#'
#' @rdname shinyFiles-parsers
#' @name shinyFiles-parsers
#'
#' @family shinyFiles
#' 
#' @importFrom tibble tibble
#' @importFrom fs path file_info path_file
#'
#' @export
#'
parseFilePaths <- function(roots, selection) {
  roots <- if (inherits(roots, "function")) roots() else roots
  
  if (is.null(selection) || is.na(selection) || is.integer(selection) || length(selection$files) == 0) {
    tibble(
      name = character(0), size = numeric(0), type = character(0),
      datapath = character(0), stringsAsFactors = FALSE
    )
  } else {
    files <- sapply(selection$files, function(x) path(roots[selection$root], paste0(x, collapse = "/")))
    tibble(name = path_file(files), size = as.numeric(file_info(files)$size), type = "", datapath = files)
  }
}
