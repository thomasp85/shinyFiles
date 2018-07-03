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
traverseDirs <- function(tree, root, restrictions, hidden) {
  location <- file.path(root, tree$name)
  if (!file.exists(location)) return(NULL)

  files <- list.files(location, all.files = hidden, full.names = TRUE, no.. = TRUE)
  files <- gsub(pattern = "//*", "/", files, perl = TRUE)
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
  fileInfo <- .file.info(files)
  folders <- basename(files)[fileInfo$isdir]

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
    currentRoots <- if (class(roots) == "function") roots() else roots

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

#' drop empty (i.e., "") from a vector
#' @param x A vector of file paths
dropEmpty <- function(x) x[!vapply(x, function(x) nchar(x) == 0, FUN.VALUE = logical(1))]

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
dirCreator <- function(roots, ...) {
  function(name, path, root) {
    currentRoots <- if (class(roots) == "function") roots() else roots

    if (is.null(names(currentRoots))) stop("Roots must be a named vector or a function returning one")
    ## drop paths with only "" to avoid //
    location <- do.call(file.path, as.list(dropEmpty(c(currentRoots[root], path, name))))
    dir.create(location)
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
#' @export
#'
#' @importFrom shiny observe invalidateLater req
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

  observe({
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
      files$dir <- do.call(file.path, as.list(files$dir))
      content <- do.call(fileGet, files)
      newDir$content <- content$files[, c("filename", "extension", "isdir", "size"), drop = FALSE]
      newDir$writable <- content$writable
    }
    currentDir <<- newDir
    session$sendCustomMessage("shinyDirectories", list(id = clientId, dir = newDir))
    if (updateFreq > 0) invalidateLater(updateFreq, session)
  })
}
#' @rdname shinyFiles-buttons
#'
#' @importFrom htmltools tagList singleton tags
#' @importFrom shiny restoreInput
#'
#' @export
#'
shinyDirButton <- function(id, label, title, buttonType="default", class=NULL, icon=NULL) {
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
#' @export
#'
shinyDirLink <- function(id, label, title, class=NULL, icon=NULL) {
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
      "data-title" = title,
      "data-val" = value,
      list(icon, as.character(label))
    )
  )
}
#' @rdname shinyFiles-parsers
#'
#' @export
#'
parseDirPath <- function(roots, selection) {
  currentRoots <- if (class(roots) == "function") roots() else roots

  if (is.null(names(currentRoots))) stop("Roots must be a named vector or a function returning one")

  if (is.integer(selection)) {
    character(0)
  } else {
    do.call(file.path, as.list(dropEmpty(c(currentRoots[selection$root], selection$path))))
  }
}
