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
#' Collapsed children are not listed, so they are reported as non-empty until
#' expanded.
#'
#' @param tree A list representing the tree structure of the file system to
#' traverse. Each element should at least contain the elements 'name' and
#' 'expanded'. The elements 'empty' and 'children' will be created or updates if
#' they exist.
#'
#' @param root A string with the location of the root folder for the tree
#'
#' @param restrictions A vector of absolute paths to directories within the
#' root that should be filtered out of the results, together with everything
#' inside them. A path only matches whole folders, so restricting `/data` hides
#' `/data` but not `/data2`.
#'
#' @param hidden A logical value specifying whether hidden folders should be
#' returned or not
#'
#' @param cache An optional listing cache (see `listingCache()`). Folders
#' already listed in it are not read again.
#'
#' @return A list of the same format as 'tree', but with updated values to
#' reflect the current file system state.
#'
#' @importFrom fs path dir_ls file_info path_file
#'
traverseDirs <- function(tree, root, restrictions, hidden, cache = NULL) {
  location <- path(root, tree$name)
  folders <- folderNamesIn(location, restrictions, hidden, cache)
  if (is.null(folders)) return(NULL)

  if (length(folders) == 0) {
    tree$empty <- TRUE
    tree$children <- list()
    tree$expanded <- FALSE
  } else {
    tree$empty <- FALSE
    if (tree$expanded) {
      children <- updateChildren(tree$children, folders)
      tree$children <- lapply(children, function(child) {
        # Listing a collapsed folder only to learn whether to draw its expand
        # arrow was most of the cost of the tree on network filesystems, so it
        # is not done here: the folder is offered as expandable, and
        # shinyDirChoose() checks it in the background after the response has
        # gone out (see `dirProber()`). Whatever that has already found is
        # used. One already marked empty is re-checked, so a folder created in
        # it still shows up.
        if (isTRUE(child$expanded) || isTRUE(child$empty)) {
          traverseDirs(child, root = location, restrictions = restrictions, hidden = hidden, cache = cache)
        } else {
          known <- peekCached(cache, folderKey(path(location, child$name)))
          child$empty <- !is.null(known) && length(known) == 0
          child$children <- list()
          child
        }
      })
    } else {
      tree$children <- list()
    }
  }
  tree
}

#' A store of directory listings for one open dialog
#'
#' The client sends its whole tree with every click, so without this each click
#' re-read every expanded folder even though only one branch changed. Listings
#' are kept until the owner clears the cache, which it does whenever the user
#' could expect to see changes made outside the dialog: reopening it, the
#' refresh button, an `updateFreq` tick, or creating a folder.
#'
#' A key may map to `NULL` (a folder that no longer exists), so presence is
#' tracked separately from the value.
#'
#' @noRd
#'
listingCache <- function() {
  store <- new.env(parent = emptyenv())
  list(
    get = function(key, compute) {
      if (exists(key, envir = store, inherits = FALSE)) {
        return(get(key, envir = store, inherits = FALSE))
      }
      value <- compute()
      assign(key, value, envir = store)
      value
    },
    peek = function(key) {
      if (exists(key, envir = store, inherits = FALSE)) get(key, envir = store, inherits = FALSE)
    },
    clear = function() rm(list = ls(store, all.names = TRUE), envir = store)
  )
}

#' Look a value up in an optional listing cache
#'
#' @noRd
#'
cached <- function(cache, key, compute) {
  if (is.null(cache)) compute() else cache$get(key, compute)
}

#' A cached value if there is one, without computing it
#'
#' Returns `NULL` both when nothing is cached and when the cached value is
#' `NULL`; callers here treat both as "unknown".
#'
#' @noRd
#'
peekCached <- function(cache, key) {
  if (is.null(cache)) NULL else cache$peek(key)
}

#' Cache key for the folder names inside `location`
#'
#' @noRd
#'
folderKey <- function(location) paste0("folders:", location)

#' The names of the folders inside `location`, or `NULL` if it does not exist
#'
#' @noRd
#'
folderNamesIn <- function(location, restrictions, hidden, cache = NULL) {
  cached(cache, folderKey(location), function() {
    if (!dir.exists(location)) return(NULL)
    path_file(listFolders(location, restrictions, hidden))
  })
}

#' The folders directly inside a directory
#'
#' Candidates come from the entry types the listing itself returns, rather than
#' a `dir.exists()` on every entry -- on a network filesystem each of those is a
#' round trip, and most entries are files. Only folders and symlinks are then
#' checked, the latter to tell a link to a folder from a link to a file.
#'
#' @importFrom fs dir_ls
#'
#' @noRd
#'
listFolders <- function(location, restrictions, hidden) {
  candidates <- suppressWarnings(
    dir_ls(location, all = hidden, type = c("directory", "symlink"), fail = FALSE)
  )
  dropRestricted(candidates[dir.exists(candidates)], restrictions)
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
#' @param restrictions A vector of absolute paths to directories within the
#' root that should be filtered out of the results, together with everything
#' inside them. A path only matches whole folders, so restricting `/data` hides
#' `/data` but not `/data2`.
#'
#' @param filetypes,pattern Currently unused. Accepted so that
#' [shinyDirChoose()] can pass the same arguments to every helper; they only
#' filter the file pane, which [fileGetter()] builds.
#'
#' @param hidden A logical value specifying whether hidden files should be
#' returned or not
#'
#' @return A function taking a list representation of a folder hierarchy along
#' with the name of the root where it starts, and optionally a listing cache.
#' See [traverseDirs()] for a description of the format for the list
#' representation.
#'
dirGetter <- function(roots, restrictions, filetypes, pattern, hidden=FALSE) {
  if (missing(filetypes)) filetypes <- NULL
  if (missing(restrictions)) restrictions <- NULL

  function(tree, root, cache = NULL) {
    currentRoots <- if (inherits(roots, "function")) roots() else roots

    if (is.null(names(currentRoots))) stop("Roots must be a named vector or a function returning one")
    if (is.null(root)) root <- names(currentRoots)[1]

    tree <- traverseDirs(tree, currentRoots[root], restrictions, hidden, cache)
    
    list(
      tree = tree,
      rootNames = I(names(currentRoots)),
      selectedRoot = root,
      rootPath = unname(currentRoots[root])
    )
  }
}

#' Find the empty folders in a tree without holding up the response
#'
#' Collapsed folders are not listed when the tree is built (see
#' [traverseDirs()]), so each is drawn with an expand arrow whether or not it
#' has subfolders. `pending()` names the collapsed folders whose contents are
#' not known yet, top to bottom as they are drawn, as full paths; `probe()`
#' lists one of them into the cache and says whether it is empty.
#'
#' `pending()` takes the root's path rather than its name: `roots` may be a
#' function, and an expensive one (it can query the system for mounted
#' volumes), so the path already resolved for the response is reused instead of
#' calling it again.
#'
#' Takes the same arguments as [dirGetter()], so both can be built from `...`.
#'
#' @noRd
#'
dirProber <- function(roots, restrictions, filetypes, pattern, hidden = FALSE) {
  if (missing(restrictions)) restrictions <- NULL

  list(
    pending = function(tree, rootPath, cache) {
      if (length(rootPath) != 1 || is.na(rootPath)) return(list())
      found <- list()
      walk <- function(node, location, segments) {
        if (!isTRUE(node$expanded)) return()
        for (child in node$children) {
          childLocation <- path(location, child$name)
          childSegments <- c(segments, as.character(child$name))
          if (isTRUE(child$expanded)) {
            walk(child, childLocation, childSegments)
          } else if (!isTRUE(child$empty) && is.null(peekCached(cache, folderKey(childLocation)))) {
            found[[length(found) + 1]] <<- list(location = childLocation, segments = childSegments)
          }
        }
      }
      walk(tree, path(rootPath, tree$name), character(0))
      found
    },
    probe = function(location, cache) {
      folders <- folderNamesIn(location, restrictions, hidden, cache)
      !is.null(folders) && length(folders) == 0
    }
  )
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
#' Build an expanded tree along a path
#'
#' The directory chooser renders a tree, and a node is only recursed into when
#' its `expanded` flag is set. Jumping to a typed path therefore needs the whole
#' chain from the root expanded, otherwise the destination is not rendered.
#'
#' @param segments A character vector of path segments below the root.
#'
#' @return A tree shell suitable for [traverseDirs()].
#'
#' @noRd
#'
expandedTreeAlong <- function(segments) {
  tree <- list(name = "", expanded = TRUE, children = list())
  if (length(segments) == 0) return(tree)

  # Built from the leaf up, so each parent gets its already-expanded child.
  node <- list(name = segments[length(segments)], expanded = TRUE, children = list())
  for (i in rev(seq_len(length(segments) - 1))) {
    node <- list(name = segments[i], expanded = TRUE, children = list(node))
  }
  tree$children <- list(node)
  tree
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
#' @importFrom shiny observe invalidateLater req observeEvent showNotification p
#'
#' @export
#'
shinyDirChoose <- function(
  input, id, updateFreq = 0, session = getSession(),
  defaultPath = "", defaultRoot = NULL, allowDirCreate = TRUE, recent = 10, ...
) {
  dirGet <- do.call(dirGetter, list(...))
  fileGet <- do.call(fileGetter, list(...))
  dirCreate <- do.call(dirCreator, list(...))
  prober <- do.call(dirProber, list(...))
  currentDir <- list()
  currentFiles <- NULL
  lastDirCreate <- NULL
  lastRequest <- NULL
  cache <- listingCache()
  probeRun <- 0
  clientId <- session$ns(id)

  # Lists the collapsed folders just sent, a slice at a time, and tells the
  # client which are empty so it can drop their arrows. It runs after the
  # response has gone out and yields between slices, so the tree shows at once
  # and clicks are still answered while it works. A newer response supersedes
  # it; what it found stays cached, so the next run skips those folders.
  probeEmptyFolders <- function(tree, root, rootPath) {
    probeRun <<- probeRun + 1
    run <- probeRun
    pending <- NULL

    probeSlice <- function() {
      if (run != probeRun || isTRUE(session$isClosed())) return()
      # Worked out here rather than up front, so not even the walk over the
      # tree holds up the response.
      if (is.null(pending)) pending <<- prober$pending(tree, rootPath, cache)
      started <- Sys.time()
      empty <- list()
      while (length(pending) > 0 && difftime(Sys.time(), started, units = "secs") < 0.02) {
        folder <- pending[[1]]
        pending <<- pending[-1]
        if (prober$probe(folder$location, cache)) empty[[length(empty) + 1]] <- I(folder$segments)
      }
      if (length(empty) > 0) {
        session$sendCustomMessage(
          "shinyDirectories-empty",
          list(id = clientId, root = root, paths = empty)
        )
      }
      if (length(pending) > 0) later::later(probeSlice, 0.01)
    }
    later::later(probeSlice, 0.01)
  }
  
  sendDirectoryData <- function(message) {
    req(input[[id]])
    tree <- input[[paste0(id, "-modal")]]
    createDir <- input[[paste0(id, "-newDir")]]

    # The client never resends an unchanged input, so a request identical to
    # the last one is the refresh button or an updateFreq tick: both mean "look
    # again". A new click count on the button means the dialog was reopened.
    # Closing with a selection also changes input[[id]], but to a list, and
    # nothing needs re-reading for that.
    request <- list(open = input[[id]], tree = tree)
    reopened <- !is.list(request$open) && !identical(request$open, lastRequest$open)
    if (reopened || identical(request, lastRequest)) cache$clear()
    lastRequest <<- request
    
    # Show a notification if a user is trying to create a 
    # new directory when that option has been disabled 
    if (!identical(createDir, lastDirCreate)) {
      if (allowDirCreate) {
        dirCreate(createDir$name, createDir$path, createDir$root)
        cache$clear()
        lastDirCreate <<- createDir
      } else {
        shiny::showNotification(shiny::p('Creating directories has been disabled.'), type = 'error')
        lastDirCreate <<- createDir
      }
    }
    
    exist <- TRUE
    if (.is_not(tree)) {
      dir <- list(tree = list(name = defaultPath, expanded = TRUE), root = defaultRoot)
      files <- list(dir = NA, root = tree$selectedRoot)
    } else {
      passedRoots <- list(...)$roots
      passedPathRoots <- if (inherits(passedRoots, "function")) passedRoots() else passedRoots

      # Text typed into the path box may name an absolute location in any root,
      # which only the server can match against the configured roots. The tree
      # is expanded here too: the client cannot know which root the text landed
      # in, so it cannot build the chain that makes the destination render.
      typed <- tree$typed
      resolved <- if (is.character(typed) && length(typed) == 1) {
        resolveTypedPath(passedRoots, typed, tree$selectedRoot)
      } else {
        NULL
      }

      if (!is.null(resolved)) {
        dir <- list(tree = expandedTreeAlong(resolved$path), root = resolved$root)
        files <- list(dir = c("", resolved$path), root = resolved$root)
        exist <- dir.exists(do.call(path, c(
          list(passedPathRoots[resolved$root]), as.list(resolved$path)
        )))
      } else {
        dir <- list(tree = tree$tree, root = tree$selectedRoot)
        files <- list(dir = unlist(tree$contentPath), root = tree$selectedRoot)
        if (is.character(typed) && length(typed) == 1) {
          # Outside every root: report a missing folder rather than navigating.
          exist <- FALSE
        } else {
          passedPath <- list(passedPathRoots[tree$selectedRoot])
          exist <- dir.exists(do.call(path, c(passedPath, files$dir[-1])))
        }
      }
    }
    newDir <- do.call(dirGet, c(dir, list(cache = cache)))
    # Only the server needs the filesystem path behind the root name.
    rootPath <- newDir$rootPath
    newDir$rootPath <- NULL
    if (.is_not(files$dir)) {
      newDir$content <- NA
      newDir$contentPath <- NA
      newDir$writable <- FALSE
    } else {
      newDir$contentPath <- as.list(files$dir)
      files$dir <- paste0(files$dir, collapse = "/")
      # Highlighting a folder lists it for the content pane, and that listing
      # was re-read on every later click while the folder stayed highlighted.
      content <- cached(cache, paste0("content:", files$root, ":", files$dir), function() {
        do.call(fileGet, files)
      })
      newDir$content <- content$files
      newDir$writable <- content$writable
    }
    newDir$exist <- exist
    newDir$root <- files$root
    newDir$recentLimit <- recent
    currentDir <<- newDir
    session$sendCustomMessage(message, list(id = clientId, dir = newDir))
    probeEmptyFolders(newDir$tree, newDir$selectedRoot, rootPath)
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
shinyDirButton <- function(
  id, label, title, buttonType="default", 
  class=NULL, icon=NULL, style=NULL, ...
) {
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
      list(icon, as.character(label)),
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
shinyDirLink <- function(id, label, title, class=NULL, icon=NULL, style=NULL, ...) {
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
      list(icon, as.character(label)),
      ...
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
