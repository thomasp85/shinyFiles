# End-to-end tests for keeping multiple shinyFiles modals independent.
#
# Reported upstream as shinyFiles/shinyFiles#201 (via @Tazovsky): with two
# shinyFilesButton/shinyDirChoose/shinySaveButton instances open at once, the
# global keydown (Enter/Escape) and backdrop-click handlers queried
# `.sF-modalContainer` without `:visible`, so they always acted on the first
# modal in the DOM rather than the topmost one -- a selection made in a later
# -opened modal was silently ignored on Enter.
#
# Two things needed fixing beyond the upstream PR:
# - It re-wrapped `.data('button')` as a raw DOM node instead of a jQuery
#   object (`visibleModal.data('button')` instead of
#   `$(visibleModal.data('button'))`), which breaks the Enter shortcut for
#   every chooser (not just the multi-modal case) with a
#   `.hasClass is not a function` TypeError.
# - It picked `.first()` among `:visible` modals. Modals are appended to
#   `<body>` in open order, so the most-recently-opened one is last in the
#   DOM and, per a real elementFromPoint hit-test, the only one actually
#   reachable by a click -- `.first()` silently targets the wrong (buried)
#   modal. `.last()` is correct.


library(shinytest2)

skipUnlessBrowser <- function() {
  skip_if_not_installed("shinytest2")
  skip_if_not_installed("chromote")
  skip_on_cran()
}

appDir <- local({
  dir <- fs::path(tempfile("sf-mm-e2e"))
  fs::dir_create(fs::path(dir, "data"))
  fs::file_create(fs::path(dir, "data", "fileA.txt"))
  fs::file_create(fs::path(dir, "data", "fileB.txt"))

  writeLines(
    c(
      'library(shiny)',
      'library(shinyFiles)',
      'base <- Sys.getenv("SF_MM_E2E_BASE")',
      'roots <- c(data = file.path(base, "data"))',
      'ui <- fluidPage(',
      '  shinyFilesButton("fileA", "Pick file A", "Pick A", multiple = FALSE),',
      '  shinyFilesButton("fileB", "Pick file B", "Pick B", multiple = FALSE),',
      '  verbatimTextOutput("pathA"),',
      '  verbatimTextOutput("pathB")',
      ')',
      'server <- function(input, output, session) {',
      '  shinyFileChoose(input, "fileA", roots = roots)',
      '  shinyFileChoose(input, "fileB", roots = roots)',
      '  output$pathA <- renderText({',
      '    req(input$fileA)',
      '    fi <- parseFilePaths(roots, input$fileA)',
      '    if (nrow(fi) == 0) "" else as.character(fi$datapath[[1]])',
      '  })',
      '  output$pathB <- renderText({',
      '    req(input$fileB)',
      '    fi <- parseFilePaths(roots, input$fileB)',
      '    if (nrow(fi) == 0) "" else as.character(fi$datapath[[1]])',
      '  })',
      '}',
      'shinyApp(ui, server)'
    ),
    fs::path(dir, "app.R")
  )
  as.character(fs::path_real(dir))
})

base <- appDir

withr::local_envvar(c(SF_MM_E2E_BASE = base), .local_envir = teardown_env())

openTwoModals <- function(app) {
  app$click("fileA")
  app$wait_for_idle()
  app$click("fileB")
  app$wait_for_idle()
}

selectFileIn <- function(app, modalId, filename) {
  app$run_js(sprintf("
    var modal = $('#%s');
    var el = modal.find('.sF-fileList').children().filter(function(){
      return $(this).text().indexOf('%s') !== -1;
    })[0];
    el.dispatchEvent(new MouseEvent('click', {bubbles: true, cancelable: true}));
  ", modalId, filename))
  app$wait_for_idle()
}

pressEnterGlobally <- function(app) {
  app$run_js("
    var e = $.Event('keydown');
    e.keyCode = 13;
    $(document).trigger(e);
  ")
  app$wait_for_idle()
}

# req() leaves an output unset until its input exists, which get_value()
# surfaces as a validation-error list rather than "" -- normalize both to "".
outputPath <- function(app, outputId) {
  v <- app$get_value(output = outputId)
  if (is.list(v)) "" else v
}

test_that("both buttons can have an open modal at the same time", {
  skipUnlessBrowser()
  app <- AppDriver$new(appDir, name = "mm-both-open", load_timeout = 30000)
  on.exit(app$stop(), add = TRUE)

  openTwoModals(app)

  expect_equal(app$get_js("$('.sF-modalContainer:visible').length"), 2)
})

test_that("Enter commits a selection made in the second (later-opened) modal", {
  skipUnlessBrowser()
  app <- AppDriver$new(appDir, name = "mm-enter-second", load_timeout = 30000)
  on.exit(app$stop(), add = TRUE)

  openTwoModals(app)
  selectFileIn(app, "fileB-modal", "fileB.txt")
  pressEnterGlobally(app)

  expect_equal(outputPath(app, "pathB"), as.character(fs::path(base, "data", "fileB.txt")))
  expect_equal(outputPath(app, "pathA"), "")
})

test_that("Enter still commits a selection made while a modal is the only one open", {
  skipUnlessBrowser()
  app <- AppDriver$new(appDir, name = "mm-enter-first", load_timeout = 30000)
  on.exit(app$stop(), add = TRUE)

  app$click("fileA")
  app$wait_for_idle()
  selectFileIn(app, "fileA-modal", "fileA.txt")
  pressEnterGlobally(app)

  expect_equal(outputPath(app, "pathA"), as.character(fs::path(base, "data", "fileA.txt")))
  expect_equal(outputPath(app, "pathB"), "")
})

test_that("Enter acts on the topmost modal, not a stale selection in a buried one", {
  skipUnlessBrowser()
  # Once a second modal opens on top, the first is behind the backdrop and
  # not reachable by a real click -- only the topmost modal should ever
  # receive the Enter shortcut, regardless of what was selected earlier.
  app <- AppDriver$new(appDir, name = "mm-enter-buried", load_timeout = 30000)
  on.exit(app$stop(), add = TRUE)

  app$click("fileA")
  app$wait_for_idle()
  selectFileIn(app, "fileA-modal", "fileA.txt")

  app$click("fileB")
  app$wait_for_idle()
  pressEnterGlobally(app)

  expect_equal(outputPath(app, "pathA"), "")
  expect_equal(outputPath(app, "pathB"), "")
})

jsErrorCount <- function(app) {
  logs <- app$get_logs()
  sum(logs$level == "error")
}

test_that("pressing Enter raises no JS error in the browser console", {
  skipUnlessBrowser()
  app <- AppDriver$new(appDir, name = "mm-enter-no-js-error", load_timeout = 30000)
  on.exit(app$stop(), add = TRUE)

  openTwoModals(app)
  selectFileIn(app, "fileB-modal", "fileB.txt")

  errorsBefore <- jsErrorCount(app)
  pressEnterGlobally(app)
  errorsAfter <- jsErrorCount(app)

  expect_equal(errorsAfter, errorsBefore)
})
