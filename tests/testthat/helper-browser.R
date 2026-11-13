# Shared helpers for the browser-driven (shinytest2) tests. testthat sources
# helper files before every test file.

# Browser tests need shinytest2, chromote and a Chrome binary, and are skipped
# on CRAN.
skipUnlessBrowser <- function() {
  skip_on_cran()
  skip_if_not_installed("shinytest2")
  skip_if_not_installed("chromote")
  skip_if(
    is.null(tryCatch(chromote::find_chrome(), error = function(e) NULL)),
    "no Chrome/Chromium found"
  )
}

# How a generated app should load shinyFiles. Under devtools::test() the package
# is a dev load, and `library(shinyFiles)` in the app's own R process would pick
# up whatever version is installed instead of this checkout.
shinyFilesLoadLine <- function() {
  if (requireNamespace("pkgload", quietly = TRUE) && pkgload::is_dev_package("shinyFiles")) {
    src <- pkgload::pkg_path(system.file(package = "shinyFiles"))
    sprintf("pkgload::load_all(%s, quiet = TRUE, export_all = FALSE)", deparse(src))
  } else {
    "library(shinyFiles)"
  }
}

# Writes an app.R into a fresh temp folder and returns the folder. `lines` is the
# app's code after the library() calls.
writeTestApp <- function(lines, prefix = "sf-app") {
  dir <- tempfile(prefix)
  dir.create(dir)
  writeLines(c("library(shiny)", shinyFilesLoadLine(), lines), file.path(dir, "app.R"))
  normalizePath(dir)
}

# Waits until the page has painted the given element, not just until Shiny is
# idle: under load the gap between the two is long enough for a click to miss.
waitForSelector <- function(app, selector = "body", timeout = 20000) {
  app$wait_for_idle(timeout = timeout)
  app$wait_for_js(
    sprintf("document.querySelector(%s) !== null", jsonlite::toJSON(selector, auto_unbox = TRUE)),
    timeout = timeout
  )
  invisible(app)
}

newApp <- function(appDir, name, ready = "button.action-button", ...) {
  app <- shinytest2::AppDriver$new(
    appDir, name = name,
    height = 900, width = 1400,
    load_timeout = 30000, timeout = 30000,
    screenshot_args = FALSE, expect_values_screenshot_args = FALSE,
    ...
  )
  waitForSelector(app, ready)
  app
}

# Errors raised in an observer are logged and swallowed, so a test can pass
# while the dialog is quietly broken. shinytest2 files R output under "shiny".
expectNoAppErrors <- function(app, label = NULL) {
  logs <- as.data.frame(app$get_logs())
  msgs <- logs$message[logs$location %in% "shiny"]
  errs <- grep("^\\s*(Warning: Error\\b|Error in\\b|Error:)", msgs, value = TRUE)
  expect_equal(errs, character(0), label = paste(c(label, "app errors"), collapse = ": "))
}

# AppDriver$stop() closes its tab but leaves the shared browser running, so
# reap it when the test file is done.
closeTestBrowser <- function() {
  if (!requireNamespace("chromote", quietly = TRUE)) return(invisible(NULL))
  has <- tryCatch(chromote::has_default_chromote_object(), error = function(e) FALSE)
  if (!isTRUE(has)) return(invisible(NULL))
  obj <- chromote::default_chromote_object()
  # Get the process before close(): asking afterwards would start a new browser.
  proc <- tryCatch(obj$get_browser()$get_process(), error = function(e) NULL)
  tryCatch(obj$close(), error = function(e) NULL)
  if (!is.null(proc) && isTRUE(tryCatch(proc$is_alive(), error = function(e) FALSE))) {
    tryCatch(proc$kill(), error = function(e) NULL)
  }
  invisible(NULL)
}

local({
  env <- tryCatch(testthat::teardown_env(), error = function(e) NULL)
  if (!is.null(env)) withr::defer(closeTestBrowser(), envir = env)
})
