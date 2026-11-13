# Adversarial tests for the per-dialog listing cache in shinyDirChoose().
#
# The client sends its whole tree with every click, and the server used to
# re-read every expanded folder each time. Listings are now kept for as long
# as the dialog stays open, and dropped when the user could expect to see
# changes made outside the dialog: reopening it, refresh, an updateFreq tick,
# or creating a folder. These tests try to make it serve stale or crossed-over
# listings.
#
# shinyDirChoose() is driven through testServer(), playing the client's side:
# every request is the last response round-tripped through Shiny's own JSON
# encoding, with only the field a click changes.

library(shiny)

makeTree <- function() {
  base <- fs::path(tempfile("sf-cache"))
  fs::dir_create(fs::path(base, "one", c("a", "b")))
  fs::dir_create(fs::path(base, "two", "c"))
  fs::dir_create(fs::path(base, "three"))
  fs::file_create(fs::path(base, "one", "file1.txt"))
  as.character(fs::path_real(base))
}

roundTrip <- function(x) {
  jsonlite::fromJSON(as.character(shiny:::toJSON(x)), simplifyVector = FALSE)
}

childNames <- function(node) {
  sort(vapply(node$children, function(ch) as.character(ch$name), character(1)))
}

findChild <- function(node, name) {
  Filter(function(ch) identical(ch$name, name), node$children)[[1]]
}

toggle <- function(tree, path) {
  if (length(path) == 0) {
    tree$expanded <- !isTRUE(tree$expanded)
    return(tree)
  }
  i <- which(vapply(tree$children, function(ch) identical(ch$name, path[[1]]), logical(1)))
  tree$children[[i]] <- toggle(tree$children[[i]], path[-1])
  tree
}

# Runs `body` against a live shinyDirChoose(). Inside it:
#   last()         the client's copy of the latest response
#   click(f, v)    send the latest response with field f replaced by v
#   expand(...)    toggle the folder at the given path
#   highlight(...) highlight the folder at the given path
#   refresh()      the refresh button
#   reopen()       close and reopen the dialog
#   listed()       folders read from disk since the last reset_listed()
withDialog <- function(roots, body, id = "dir", ...) {
  args <- list(...)
  server <- function(input, output, session) {
    do.call(shinyDirChoose, c(list(input, id, roots = roots, session = session), args))
  }
  testServer(server, {
    state <- new.env()
    state$last <- NULL
    state$listed <- character(0)
    state$opens <- 0
    session$sendCustomMessage <- function(type, message) {
      if (identical(type, "shinyDirectories-empty")) return()
      if (identical(message$id, session$ns(id))) state$last <- roundTrip(message$dir)
    }
    realDirLs <- fs::dir_ls
    local_mocked_bindings(
      dir_ls = function(path = ".", ...) {
        state$listed <- c(state$listed, as.character(path))
        realDirLs(path, ...)
      },
      .package = "shinyFiles"
    )

    send <- function(data) do.call(session$setInputs, setNames(list(data), paste0(id, "-modal")))
    api <- list(
      last = function() state$last,
      click = function(field, value) {
        data <- state$last
        data[field] <- list(value)
        send(data)
      },
      expand = function(...) {
        data <- state$last
        data$tree <- toggle(data$tree, list(...))
        send(data)
      },
      highlight = function(...) {
        data <- state$last
        data$contentPath <- c(list(""), list(...))
        send(data)
      },
      refresh = function() {
        do.call(session$setInputs, setNames(list(as.numeric(Sys.time()) + runif(1)), paste0(id, "-refresh")))
      },
      reopen = function() {
        state$opens <- state$opens + 1
        do.call(session$setInputs, setNames(list(state$opens), id))
      },
      newDir = function(name, ...) {
        do.call(session$setInputs, setNames(list(list(
          name = name, path = c(list(""), list(...)), root = state$last$selectedRoot,
          id = as.numeric(Sys.time()) + runif(1)
        )), paste0(id, "-newDir")))
      },
      listed = function() basename(state$listed),
      reset_listed = function() state$listed <- character(0),
      session = session
    )
    api$reopen()
    # The first request after opening carries the root expanded, no highlight.
    data <- state$last
    data$tree <- list(name = "", expanded = TRUE)
    data["contentPath"] <- list(NULL)
    send(data)
    body(api)
  })
}

# --- the point of it: no re-reads -------------------------------------------

test_that("clicks inside an open dialog do not re-read folders already listed", {
  base <- makeTree()
  withDialog(c(r = base), function(d) {
    d$expand("one")
    d$reset_listed()
    d$expand("two")
    expect_equal(d$listed(), "two")

    d$reset_listed()
    d$expand("one", "a")
    expect_equal(d$listed(), "a")

    d$reset_listed()
    d$expand("two") # collapse
    expect_length(d$listed(), 0)
  })
})

test_that("a highlighted folder's contents are not re-read on later clicks", {
  base <- makeTree()
  withDialog(c(r = base), function(d) {
    d$highlight("one")
    expect_true("file1.txt" %in% unlist(d$last()$content$filename))
    d$reset_listed()
    d$expand("two")
    expect_equal(d$listed(), "two")
    expect_true("file1.txt" %in% unlist(d$last()$content$filename))
  })
})

# --- equivalence: cached answers match a fresh read -------------------------

test_that("every response matches what an uncached read of the same tree gives", {
  base <- makeTree()
  fresh <- dirGetter(roots = c(r = base))
  withDialog(c(r = base), function(d) {
    check <- function() {
      got <- d$last()
      want <- roundTrip(fresh(tree = got$tree, root = "r"))
      expect_equal(got$tree, want$tree)
    }
    d$expand("one"); check()
    d$expand("two"); check()
    d$expand("one", "a"); check()
    d$highlight("two", "c"); check()
    d$expand("one"); check()
    d$expand("one"); check()
  })
})

# --- invalidation ------------------------------------------------------------

test_that("refresh shows a folder created outside the dialog", {
  base <- makeTree()
  withDialog(c(r = base), function(d) {
    d$expand("one")
    fs::dir_create(fs::path(base, "one", "outside"))
    d$expand("two")
    # Not seen yet: listings are kept while the dialog is open.
    expect_false("outside" %in% childNames(findChild(d$last()$tree, "one")))
    d$refresh()
    expect_true("outside" %in% childNames(findChild(d$last()$tree, "one")))
  })
})

test_that("refresh drops a folder deleted outside the dialog", {
  base <- makeTree()
  withDialog(c(r = base), function(d) {
    d$expand("one")
    d$expand("one", "a")
    fs::dir_delete(fs::path(base, "one", "a"))
    d$refresh()
    expect_false("a" %in% childNames(findChild(d$last()$tree, "one")))
  })
})

test_that("refresh shows a file added to the highlighted folder", {
  base <- makeTree()
  withDialog(c(r = base), function(d) {
    d$highlight("one")
    fs::file_create(fs::path(base, "one", "late.txt"))
    d$refresh()
    expect_true("late.txt" %in% unlist(d$last()$content$filename))
  })
})

test_that("reopening the dialog shows changes made while it was closed", {
  base <- makeTree()
  withDialog(c(r = base), function(d) {
    d$expand("one")
    fs::dir_create(fs::path(base, "one", "whileClosed"))
    d$reopen()
    d$click("tree", d$last()$tree) # the client resends its tree
    expect_true("whileClosed" %in% childNames(findChild(d$last()$tree, "one")))
  })
})

test_that("a folder created with the dialog's new-folder button appears at once", {
  base <- makeTree()
  withDialog(c(r = base), function(d) {
    d$expand("one")
    d$newDir("made", "one")
    expect_true(fs::dir_exists(fs::path(base, "one", "made")))
    expect_true("made" %in% childNames(findChild(d$last()$tree, "one")))
  })
})

test_that("a folder created inside an empty one makes it expandable", {
  base <- makeTree()
  withDialog(c(r = base), function(d) {
    d$expand("three")
    expect_true(findChild(d$last()$tree, "three")$empty)
    d$newDir("inner", "three")
    expect_false(findChild(d$last()$tree, "three")$empty)
  })
})

test_that("the new-folder button is refused when allowDirCreate is FALSE", {
  base <- makeTree()
  notes <- list()
  local_mocked_bindings(
    showNotification = function(ui, ..., type = "default") {
      notes[[length(notes) + 1]] <<- list(text = as.character(ui), type = type)
    },
    .package = "shiny"
  )
  withDialog(c(r = base), allowDirCreate = FALSE, function(d) {
    d$newDir("blocked", "one")
    expect_false(fs::dir_exists(fs::path(base, "one", "blocked")))
    # The same request isn't reported again on the next click.
    d$expand("one")
  })
  expect_length(notes, 1)
  expect_match(notes[[1]]$text, "disabled")
  expect_equal(notes[[1]]$type, "error")
})

test_that("a typed path outside every root reports a missing folder", {
  base <- makeTree()
  withDialog(c(r = base), function(d) {
    d$expand("one")
    d$click("typed", "/no/such/place/anywhere")
    expect_false(d$last()$exist)
    expect_true(findChild(d$last()$tree, "one")$expanded)
  })
})

test_that("an updateFreq tick re-reads the filesystem", {
  base <- makeTree()
  withDialog(c(r = base), updateFreq = 1000, function(d) {
    d$expand("one")
    fs::dir_create(fs::path(base, "one", "ticked"))
    d$session$elapse(1500)
    expect_true("ticked" %in% childNames(findChild(d$last()$tree, "one")))
  })
})

# --- no crossed wires --------------------------------------------------------

test_that("same-named folders in different roots are not confused", {
  a <- makeTree()
  b <- fs::path(tempfile("sf-cache-b"))
  fs::dir_create(fs::path(b, "one", "onlyInB"))
  b <- as.character(fs::path_real(b))

  withDialog(c(ra = a, rb = b), function(d) {
    d$expand("one")
    expect_equal(childNames(findChild(d$last()$tree, "one")), c("a", "b"))

    # Switch volume as changeVolume does: tree reset, nothing highlighted.
    data <- d$last()
    data$selectedRoot <- "rb"
    data$tree <- list(name = "", expanded = TRUE)
    data["contentPath"] <- list(NULL)
    d$session$setInputs(`dir-modal` = data)
    d$expand("one")
    expect_equal(childNames(findChild(d$last()$tree, "one")), "onlyInB")
  })
})

test_that("two folder choosers keep separate caches", {
  base <- makeTree()
  server <- function(input, output, session) {
    shinyDirChoose(input, "d1", roots = c(r = base), session = session)
    shinyDirChoose(input, "d2", roots = c(r = base), session = session)
  }
  testServer(server, {
    got <- list()
    session$sendCustomMessage <- function(type, message) {
      if (identical(type, "shinyDirectories-empty")) return()
      got[[sub(session$ns(""), "", message$id, fixed = TRUE)]] <<- roundTrip(message$dir)
    }
    open <- function(id) {
      do.call(session$setInputs, setNames(list(1), id))
      do.call(session$setInputs, setNames(list(list(tree = list(name = "", expanded = TRUE), selectedRoot = "r")), paste0(id, "-modal")))
    }
    open("d1")
    open("d2")
    fs::dir_create(fs::path(base, "lateTop"))
    # Refreshing one dialog must not leave the other believing it is current,
    # nor make the other's stale entries visible in it.
    session$setInputs(`d1-refresh` = 1)
    expect_true("lateTop" %in% childNames(got[["d1"]]$tree))
    session$setInputs(`d2-refresh` = 1)
    expect_true("lateTop" %in% childNames(got[["d2"]]$tree))
  })
})

test_that("restrictions still apply to cached listings", {
  base <- makeTree()
  withDialog(c(r = base), restrictions = fs::path(base, "two"), function(d) {
    expect_false("two" %in% childNames(d$last()$tree))
    d$expand("one")
    d$expand("one")
    expect_false("two" %in% childNames(d$last()$tree))
  })
})

test_that("typed paths still navigate with the cache in place", {
  base <- makeTree()
  withDialog(c(r = base), function(d) {
    d$expand("one")
    d$click("typed", as.character(fs::path(base, "two", "c")))
    expect_equal(unlist(d$last()$contentPath), c("", "two", "c"))
    expect_true(findChild(d$last()$tree, "two")$expanded)
  })
})

test_that("a selection does not clear the cache", {
  base <- makeTree()
  withDialog(c(r = base), function(d) {
    d$expand("one")
    d$reset_listed()
    d$session$setInputs(dir = list(path = list("", "one"), root = "r"))
    expect_length(d$listed(), 0)
  })
})

# --- background check for empty folders --------------------------------------
#
# Collapsed folders are drawn with an expand arrow without being listed. After
# the response goes out, the server lists them in slices on the event loop and
# sends "shinyDirectories-empty" for those with no subfolders.

# Runs every pending later() callback, i.e. lets the background check finish.
drainLater <- function() {
  for (i in 1:1000) {
    if (!later::loop_empty()) later::run_now(0.05) else break
  }
}

emptyMessages <- function(sent) {
  Filter(function(m) identical(m$type, "shinyDirectories-empty"), sent)
}

emptyPaths <- function(sent) {
  unlist(lapply(emptyMessages(sent), function(m) {
    vapply(m$message$paths, function(p) paste(unlist(p), collapse = "/"), character(1))
  }))
}

withProbe <- function(roots, body, ...) {
  args <- list(...)
  server <- function(input, output, session) {
    do.call(shinyDirChoose, c(list(input, "dir", roots = roots, session = session), args))
  }
  testServer(server, {
    sent <- list()
    session$sendCustomMessage <- function(type, message) {
      sent[[length(sent) + 1]] <<- list(type = type, message = roundTrip(message))
    }
    open <- function(tree = list(name = "", expanded = TRUE), root = if (is.function(roots)) names(roots())[1] else names(roots)[1]) {
      session$setInputs(dir = 1)
      session$setInputs(`dir-modal` = list(tree = tree, selectedRoot = root))
    }
    body(environment())
  })
}

test_that("the tree is sent before any collapsed folder is listed", {
  base <- makeTree()
  withProbe(c(r = base), function(e) {
    listed <- character(0)
    realDirLs <- fs::dir_ls
    local_mocked_bindings(
      dir_ls = function(path = ".", ...) {
        listed <<- c(listed, basename(as.character(path)))
        realDirLs(path, ...)
      },
      .package = "shinyFiles"
    )
    e$open()
    expect_equal(e$sent[[length(e$sent)]]$type, "shinyDirectories")
    expect_false(any(c("one", "two", "three") %in% listed))
    drainLater()
    expect_true(all(c("one", "two", "three") %in% listed))
  })
})

test_that("only folders with no subfolders are reported empty", {
  base <- makeTree()
  # three: no children at all; two/c: has none either, but is not shown.
  fs::file_create(fs::path(base, "three", "onlyAFile.txt"))
  withProbe(c(r = base), function(e) {
    e$open()
    drainLater()
    expect_equal(sort(emptyPaths(e$sent)), "three")
  })
})

test_that("empty folders deep in an expanded branch are found with their full path", {
  base <- makeTree()
  withProbe(c(r = base), function(e) {
    e$open(list(name = "", expanded = TRUE, children = list(
      list(name = "one", expanded = TRUE, children = list())
    )))
    drainLater()
    expect_setequal(emptyPaths(e$sent), c("one/a", "one/b", "three"))
  })
})

test_that("the report names the root it is about", {
  base <- makeTree()
  withProbe(c(r = base), function(e) {
    e$open()
    drainLater()
    roots <- vapply(emptyMessages(e$sent), function(m) m$message$root, character(1))
    expect_true(length(roots) > 0)
    expect_true(all(roots == "r"))
  })
})

test_that("once the check has run, the next response already knows which are empty", {
  base <- makeTree()
  withProbe(c(r = base), function(e) {
    e$open()
    drainLater()
    tree <- e$sent[[1]]$message$dir$tree
    tree$children <- lapply(tree$children, function(ch) { ch$empty <- FALSE; ch })
    e$session$setInputs(`dir-modal` = list(tree = tree, selectedRoot = "r", contentPath = list("", "one")))
    last <- Filter(function(m) m$type == "shinyDirectories", e$sent)
    tree <- last[[length(last)]]$message$dir$tree
    expect_true(findChild(tree, "three")$empty)
    expect_false(findChild(tree, "one")$empty)
  })
})

test_that("nothing already known is listed again by a later check", {
  base <- makeTree()
  withProbe(c(r = base), function(e) {
    e$open()
    drainLater()
    before <- length(emptyMessages(e$sent))
    listed <- character(0)
    realDirLs <- fs::dir_ls
    local_mocked_bindings(
      dir_ls = function(path = ".", ...) {
        listed <<- c(listed, basename(as.character(path)))
        realDirLs(path, ...)
      },
      .package = "shinyFiles"
    )
    tree <- e$sent[[1]]$message$dir$tree
    e$session$setInputs(`dir-modal` = list(tree = tree, selectedRoot = "r", contentPath = list("", "two")))
    drainLater()
    expect_false(any(c("one", "three") %in% listed))
    expect_equal(length(emptyMessages(e$sent)), before)
  })
})

test_that("a newer response supersedes a check still in progress", {
  base <- fs::path(tempfile("sf-probe-many"))
  fs::dir_create(fs::path(base, sprintf("e%04d", 1:2000)))
  base <- as.character(fs::path_real(base))
  withProbe(c(r = base), function(e) {
    e$open()
    later::run_now(0.05, all = FALSE)
    # Collapse the root: the new response has nothing collapsed to check, so
    # if the old run were still going it would be the only source of reports.
    e$session$setInputs(`dir-modal` = list(tree = list(name = "", expanded = FALSE), selectedRoot = "r"))
    n <- length(emptyPaths(e$sent))
    drainLater()
    expect_equal(length(emptyPaths(e$sent)), n)
    expect_lt(n, 2000)
  })
})

test_that("the check works in slices rather than one long block", {
  base <- fs::path(tempfile("sf-probe-slices"))
  fs::dir_create(fs::path(base, sprintf("e%04d", 1:2000)))
  base <- as.character(fs::path_real(base))
  withProbe(c(r = base), function(e) {
    e$open()
    later::run_now(0.05, all = FALSE)
    first <- length(emptyPaths(e$sent))
    expect_gt(first, 0)
    expect_lt(first, 2000)
    drainLater()
    expect_length(emptyPaths(e$sent), 2000)
  })
})

test_that("the check stops when the session ends", {
  base <- fs::path(tempfile("sf-probe-closed"))
  fs::dir_create(fs::path(base, sprintf("e%04d", 1:2000)))
  base <- as.character(fs::path_real(base))
  withProbe(c(r = base), function(e) {
    e$open()
    later::run_now(0.05, all = FALSE)
    n <- length(emptyPaths(e$sent))
    e$session$close()
    drainLater()
    expect_equal(length(emptyPaths(e$sent)), n)
  })
})

test_that("restricted folders are neither probed nor reported", {
  base <- makeTree()
  withProbe(c(r = base), restrictions = fs::path(base, "three"), function(e) {
    e$open()
    drainLater()
    expect_false("three" %in% emptyPaths(e$sent))
  })
})

test_that("a folder deleted before the check reaches it is not reported", {
  base <- makeTree()
  withProbe(c(r = base), function(e) {
    e$open()
    fs::dir_delete(fs::path(base, "three"))
    drainLater()
    expect_false("three" %in% emptyPaths(e$sent))
  })
})

test_that("the check does not call an expensive roots function again", {
  base <- fs::path(tempfile("sf-probe-roots"))
  fs::dir_create(fs::path(base, sprintf("e%02d", 1:20)))
  base <- as.character(fs::path_real(base))
  calls <- 0
  roots <- function() {
    calls <<- calls + 1
    c(r = base)
  }
  withProbe(roots, function(e) {
    e$open(root = "r")
    before <- calls
    drainLater()
    expect_equal(calls - before, 0)
    expect_length(emptyPaths(e$sent), 20)
  })
})

test_that("the filesystem path behind a root is not sent to the browser", {
  base <- makeTree()
  withProbe(c(r = base), function(e) {
    e$open()
    trees <- Filter(function(m) m$type == "shinyDirectories", e$sent)
    expect_null(trees[[length(trees)]]$message$dir$rootPath)
    expect_false(grepl(base, as.character(shiny:::toJSON(trees[[length(trees)]]$message)), fixed = TRUE))
  })
})
