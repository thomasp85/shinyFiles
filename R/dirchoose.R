#' @include aaa.R
#' @include filechoose.R
#'
NULL

#' Traverse and update a tree representing the file system
#'
#' This function takes a tree representing a part of the file system and updates
#' it to reflect the current state of the file system as well as the settings
#' for each node. Children (contained folders) are recursed into if the parents
#' expanded element is set to TRUE, no matter if children are currently present.
#'
#' @param tree A list representing the tree structure of the file system to
#' traverse. Each element should at least contain the elements 'name' and
#' 'expanded'. The elements 'empty' and 'children' will be created or updates if
#' they exist.
#'
#' @param root A string with the location of the root folder for the tree
#'
#' @param restrictions A vector of directories within the root that should be
#' filtered out of the results
#'
#' @param hidden A logical value specifying whether hidden folders should be
#' returned or not
#'
#' @return A list of the same format as 'tree', but with updated values to
#' reflect the current file system state.
#'
#' @importFrom fs path dir_ls file_info path_file
#'
traverseDirs <- function(tree, root, restrictions, hidden) {
  location <- path(root, tree$name)
  if (!dir.exists(location)) return(NULL)

  files <- suppressWarnings(dir_ls(location, all = hidden, fail = FALSE))

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

  folders <- path_file(files[dir.exists(files)])

  if (length(folders) == 0) {
    tree$empty <- TRUE
    tree$children <- list()
    tree$expanded <- FALSE
  } else {
    tree$empty <- FALSE
    if (tree$expanded) {
      children <- updateChildren(tree$children, folders)
      tree$children <- lapply(children, traverseDirs, root = location, restrictions = restrictions, hidden = hidden)
    } else {
      tree$children <- list()
    }
  }
  tree
}

#' Update the children element to reflect current state
#'
#' This function create new entries for new folders and remove entries for no
#' longer existing folders, while keeping the state of transient folders in the
#' children element of the tree structure. The function does not recurse into
#' the folders, but merely creates a shell that traverseDirs can take as input.
#'
#' @param oldChildren A list of children folders from the parent$children
#' element of tree in [traverseDirs()]
#'
#' @param currentChildren A vector of names of the folders that are currently
#' present in the parent of oldChildren
#'
#' @return An updated list equal in format to oldChildren
#'
updateChildren <- function(oldChildren, currentChildren) {
  oldNames <- sapply(oldChildren, `[[`, "name")
  newChildren <- currentChildren[!currentChildren %in% oldNames]
  children <- oldChildren[oldNames %in% currentChildren]
  children <- append(children, lapply(newChildren, function(x) {
    list(name = x, expanded = FALSE, children = list())
  }))
  childrenNames <- sapply(children, `[[`, "name")
  children[order(childrenNames)]
}
#' Create a function that updates a folder tree based on the given restrictions
#'
#' This functions returns a new function that will handle updating the folder
#' tree. It is the folder equivalent of [fileGetter()] but functions
#' slightly different as it needs to handle expanded branches of the folder
#' hierarchy rather than just the content of a single directory at a time. The
#' returned function takes a representation of a folder hierarchy along with the
#' root to where it belongs and updates the tree to correspond with the current
#' state of the file system, without altering expansions etc.
#'
#' @param roots A named vector of absolute filepaths or a function returning a
#' named vector of absolute filepaths (the latter is useful if the volumes
#' should adapt to changes in the filesystem).
#'
#' @param restrictions A vector of directories within the root that should be
#' filtered out of the results
#'
#' @param filetypes Currently unused
#'
#' @param hidden A logical value specifying whether hidden files should be
#' returned or not
#'
#' @return A function taking a list representation of a folder hierarchy along
#' with the name of the root where it starts. See [traverseDirs()] for
#' a description of the format for the list representation.
#'
dirGetter <- function(roots, restrictions, filetypes, hidden=FALSE) {
  if (missing(filetypes)) filetypes <- NULL
  if (missing(restrictions)) restrictions <- NULL

  function(tree, root) {
    currentRoots <- if (inherits(roots, "function")) roots() else roots

    if (is.null(names(currentRoots))) stop("Roots must be a named vector or a function returning one")
    if (is.null(root)) root <- names(currentRoots)[1]

    tree <- traverseDirs(tree, currentRoots[root], restrictions, hidden)

    list(
      tree = tree,
      rootNames = I(names(currentRoots)),
      selectedRoot = root
    )
  }
}

#' Create a function that creates a new directory
#'
#' This function returns a function that can be used to create new directories
#' based on the information returned from the client. The returned function
#' takes the name, path and root of the directory to create and parses it into
#' a platform compliant format and then uses dir.create to create it. The
#' returned function returns TRUE if the directory was created successfully and
#' FALSE otherwise.
#'
#' @param roots A named vector of absolute filepaths or a function returning a
#' named vector of absolute filepaths (the latter is useful if the volumes
#' should adapt to changes in the filesystem).
#'
#' @param ... Currently unused
#'
#' @return A function that creates directories based on the information returned
#' by the client.
#'
#' @importFrom fs path dir_create
#'
dirCreator <- function(roots, ...) {
  function(name, path, root) {
    currentRoots <- if (inherits(roots, "function")) roots() else roots
    if (is.null(names(currentRoots))) stop("Roots must be a named vector or a function returning one")
    location <- fs::path(currentRoots[root], paste0(c(path, name), collapse = "/"))
    dir_create(location)
  }
}
#' @rdname shinyFiles-observers
#'
#' @examples
#' \dontrun{
#' # Folder selections
#' ui <- shinyUI(bootstrapPage(
#'   shinyDirButton('folder', 'Folder select', 'Please select a folder', FALSE)
#' ))
#' server <- shinyServer(function(input, output) {
#'   shinyDirChoose(input, 'folder', roots=c(wd='.'), filetypes=c('', 'txt'))
#' })
#'
#' runApp(list(
#'   ui=ui,
#'   server=server
#' ))
#' }
#'
#' @importFrom shiny observe invalidateLater req observeEvent
#'
#' @export
#'
shinyDirChoose <- function(input, id, updateFreq = 0, session=getSession(),
                           defaultPath="", defaultRoot=NULL, ...) {
  dirGet <- do.call(dirGetter, list(...))
  fileGet <- do.call(fileGetter, list(...))
  dirCreate <- do.call(dirCreator, list(...))
  currentDir <- list()
  currentFiles <- NULL
  lastDirCreate <- NULL
  clientId <- session$ns(id)

  sendDirectoryData <- function(message) {
    req(input[[id]])
    tree <- input[[paste0(id, "-modal")]]
    createDir <- input[[paste0(id, "-newDir")]]
    if (!identical(createDir, lastDirCreate)) {
      dirCreate(createDir$name, createDir$path, createDir$root)
      lastDirCreate <<- createDir
    }
    if (is.null(tree) || is.na(tree)) {
      dir <- list(tree = list(name = defaultPath, expanded = TRUE), root = defaultRoot)
      files <- list(dir = NA, root = tree$selectedRoot)
    } else {
      dir <- list(tree = tree$tree, root = tree$selectedRoot)
      files <- list(dir = unlist(tree$contentPath), root = tree$selectedRoot)
    }
    newDir <- do.call(dirGet, dir)
    if (is.null(files$dir) || is.na(files$dir)) {
      newDir$content <- NA
      newDir$contentPath <- NA
      newDir$writable <- FALSE
    } else {
      newDir$contentPath <- as.list(files$dir)
      files$dir <- paste0(files$dir, collapse = "/")
      content <- do.call(fileGet, files)
      newDir$content <- content$files
      newDir$writable <- content$writable
    }
    currentDir <<- newDir
    session$sendCustomMessage(message, list(id = clientId, dir = newDir))
    if (updateFreq > 0) invalidateLater(updateFreq, session)
  }

  observe({
    sendDirectoryData("shinyDirectories")
  })

  observeEvent(input[[paste0(id, "-refresh")]], {
    if (!is.null(input[[paste0(id, "-refresh")]])) {
      sendDirectoryData("shinyDirectories-refresh")
    }
  })
}
#' @rdname shinyFiles-buttons
#'
#' @importFrom htmltools tagList singleton tags
#' @importFrom shiny restoreInput
#'
#' @export
#'
shinyDirButton <- function(id, label, title, buttonType="default", class=NULL, icon=NULL, style=NULL) {
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
      class = paste(c("shinyDirectories btn", paste0("btn-", buttonType), class, "action-button"), collapse = " "),
      style = style,
      "data-title" = title,
      "data-val" = value,
      list(icon, as.character(label))
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
shinyDirLink <- function(id, label, title, class=NULL, icon=NULL, style=NULL) {
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
      class = paste(c("shinyDirectories", class, "action-button"), collapse = " "),
      style = style,
      "data-title" = title,
      "data-val" = value,
      list(icon, as.character(label))
    )
  )
}
#' @rdname shinyFiles-parsers
#'
#' @importFrom fs path
#'
#' @export
#'
parseDirPath <- function(roots, selection) {
  currentRoots <- if (inherits(roots, "function")) roots() else roots

  if (is.null(names(currentRoots))) stop("Roots must be a named vector or a function returning one")

  if (is.integer(selection)) {
    character(0)
  } else {
    path(currentRoots[selection$root], paste0(selection$path, collapse = "/"))
  }
}
