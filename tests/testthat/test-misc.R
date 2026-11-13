# Unit tests for the small helpers: formatFiletype(), getSession(), .onLoad()
# and shinyFilesExample().

test_that("formatFiletype encodes a named list of extensions", {
  expect_equal(as.character(formatFiletype(NA)), "[null]")
  expect_equal(
    as.character(formatFiletype(list(Excel = c("xlsx", "xls"), CSV = "csv"))),
    '[{"name":["Excel"],"ext":["xlsx","xls"]},{"name":["CSV"],"ext":["csv"]}]'
  )
  # A single extension stays an array, which the dialog iterates over.
  expect_equal(as.character(formatFiletype(list(R = "R"))), '[{"name":["R"],"ext":["R"]}]')
})

test_that("no file types is encoded as an array, like NA", {
  # The dialog calls filetypes.forEach(); an empty list encodes as {}, which
  # stopped the save dialog from opening.
  expect_equal(as.character(formatFiletype(NULL)), "[null]")
  expect_equal(as.character(formatFiletype(list())), "[null]")
  expect_equal(as.character(shinySaveButton("s", "L", "T", filetype = NULL)[[2]]$attribs[["data-filetype"]]), "[null]")
})

test_that("getSession errors outside a Shiny session", {
  expect_error(shiny::withReactiveDomain(NULL, getSession()), "could not find the Shiny session")
  session <- shiny::MockShinySession$new()
  expect_identical(shiny::withReactiveDomain(session, getSession()), session)
})

test_that("the observers default to the current session", {
  session <- shiny::MockShinySession$new()
  expect_no_error(shiny::withReactiveDomain(session, {
    shinyFileChoose(session$input, "f", roots = c(home = tempdir()))
    shinyDirChoose(session$input, "d", roots = c(home = tempdir()))
    shinyFileSave(session$input, "s", roots = c(home = tempdir()))
  }))
})

test_that(".onLoad serves the package's www folder under sF/", {
  # testthat doesn't expose dot-prefixed functions, so fetch it by name.
  onLoad <- get(".onLoad", envir = asNamespace("shinyFiles"))
  shiny::removeResourcePath("sF")
  on.exit(onLoad())
  onLoad()
  paths <- shiny::resourcePaths()
  expect_true("sF" %in% names(paths))
  expect_equal(
    normalizePath(paths[["sF"]]),
    normalizePath(system.file("www", package = "shinyFiles"))
  )
  expect_true(file.exists(file.path(paths[["sF"]], "shinyFiles.js")))
})

test_that("shinyFilesExample runs the bundled example in showcase mode", {
  called <- NULL
  local_mocked_bindings(runApp = function(...) called <<- list(...), .package = "shiny")
  shinyFilesExample()
  expect_equal(normalizePath(called[[1]]), normalizePath(system.file("example", package = "shinyFiles")))
  expect_equal(called$display.mode, "showcase")
  expect_true(all(file.exists(file.path(called[[1]], c("ui.R", "server.R")))))
})
