# End-to-end tests for the "Recent" group in the volume dropdown.
#
# A folder is remembered (in the browser's localStorage) when a selection or
# save is confirmed in it, and offered under "Recent" in every dialog on the
# page whose roots include it. Driven through a real browser because the list
# lives entirely client-side: the server only sends how many to show.

library(shinytest2)

appDir <- local({
  dir <- fs::path(tempfile("sf-recent-e2e"))
  fs::dir_create(fs::path(dir, "data", "sub", "deep"))
  fs::file_create(fs::path(dir, "data", "sub", "deep", "a.txt"))
  fs::dir_create(fs::path(dir, "other", "x"))

  writeLines(
    c(
      'library(shiny)',
      shinyFilesLoadLine(),
      'base <- Sys.getenv("SF_RECENT_E2E_BASE")',
      'roots <- c(data = file.path(base, "data"), other = file.path(base, "other"))',
      'ui <- fluidPage(',
      '  shinyFilesButton("file", "Pick file", "Pick a file", multiple = FALSE),',
      '  shinyFilesButton("file2", "Pick file 2", "Pick a file", multiple = FALSE),',
      '  shinyDirButton("dir", "Pick dir", "Pick a directory"),',
      '  shinySaveButton("save", "Save", "Save a file"),',
      '  shinyFilesButton("onlyOther", "Other only", "Pick", multiple = FALSE),',
      '  shinyFilesButton("off", "Recent off", "Pick", multiple = FALSE),',
      '  verbatimTextOutput("dirpath")',
      ')',
      'server <- function(input, output, session) {',
      '  shinyFileChoose(input, "file", roots = roots)',
      '  shinyFileChoose(input, "file2", roots = roots)',
      '  shinyDirChoose(input, "dir", roots = roots)',
      '  shinyFileSave(input, "save", roots = roots)',
      '  shinyFileChoose(input, "onlyOther", roots = roots["other"])',
      '  shinyFileChoose(input, "off", roots = roots, recent = 0)',
      '  output$dirpath <- renderText({',
      '    req(input$dir)',
      '    as.character(parseDirPath(roots, input$dir))',
      '  })',
      '}',
      'shinyApp(ui, server)'
    ),
    fs::path(dir, "app.R")
  )
  as.character(fs::path_real(dir))
})

base <- appDir

withr::local_envvar(c(SF_RECENT_E2E_BASE = base), .local_envir = teardown_env())

# --- helpers ----------------------------------------------------------------

newApp <- function(name) {
  app <- AppDriver$new(appDir, name = name, load_timeout = 30000)
  # Every AppDriver gets a fresh Chrome profile, but be explicit about it.
  app$run_js("window.localStorage.clear();")
  app
}

openDialog <- function(app, id) {
  app$click(id)
  app$wait_for_idle()
}

topModal <- "$('.sF-modalContainer:visible').last()"

# Seed the store directly, so tests that are about *showing* entries do not
# depend on the selection path working.
seedRecent <- function(app, entries) {
  json <- jsonlite::toJSON(entries, auto_unbox = TRUE)
  app$run_js(sprintf(
    "window.localStorage.setItem('shinyFiles-recent:' + window.location.pathname, '%s');",
    json
  ))
}

storedRecent <- function(app) {
  app$get_js("JSON.parse(window.localStorage.getItem('shinyFiles-recent:' + window.location.pathname) || '[]')")
}

recentLabels <- function(app) {
  vapply(app$get_js(sprintf(
    "%s.find('.sF-breadcrumps optgroup.sF-recent option').map(function(){ return $(this).text(); }).toArray()",
    topModal
  )), as.character, character(1))
}

chooseRecent <- function(app, label) {
  app$run_js(sprintf("
    var select = %s.find('.sF-breadcrumps');
    var opt = select.find('optgroup.sF-recent option').filter(function(){
      return $(this).text() === '%s';
    });
    opt.prop('selected', true);
    select.trigger('change');
  ", topModal, label))
  app$wait_for_idle()
}

currentLocation <- function(app) {
  app$get_js(sprintf(
    "%s.find('.sF-breadcrumps>option').map(function(){ return $(this).val(); }).toArray().reverse()",
    topModal
  ))
}

clickFile <- function(app, name) {
  app$run_js(sprintf("
    var el = %s.find('.sF-fileList').children().filter(function(){
      return $(this).find('.sF-file-name').text() === '%s';
    })[0];
    el.dispatchEvent(new MouseEvent('click', {bubbles: true, cancelable: true}));
  ", topModal, name))
  app$wait_for_idle()
}

openFolder <- function(app, name) {
  app$run_js(sprintf("
    var el = %s.find('.sF-fileList').children().filter(function(){
      return $(this).find('.sF-file-name').text() === '%s';
    })[0];
    el.dispatchEvent(new MouseEvent('dblclick', {bubbles: true, cancelable: true}));
  ", topModal, name))
  app$wait_for_idle()
}

clickSelect <- function(app) {
  app$run_js(sprintf("%s.find('#sF-selectButton').click();", topModal))
  app$wait_for_idle()
  # removeFileChooser tears the modal down on a 300ms timer.
  Sys.sleep(0.5)
}

entry <- function(root, ...) list(root = root, path = I(c(...)))

# --- tests ------------------------------------------------------------------

test_that("confirming a file selection remembers its folder", {
  skipUnlessBrowser()
  app <- newApp("recent-file-select")
  on.exit(app$stop(), add = TRUE)

  openDialog(app, "file")
  openFolder(app, "sub")
  openFolder(app, "deep")
  clickFile(app, "a.txt")
  clickSelect(app)

  stored <- storedRecent(app)
  expect_length(stored, 1)
  expect_equal(stored[[1]]$root, "data")
  expect_equal(unlist(stored[[1]]$path), c("sub", "deep"))
})

test_that("a remembered folder is offered in another button and navigates there", {
  skipUnlessBrowser()
  app <- newApp("recent-file-navigate")
  on.exit(app$stop(), add = TRUE)

  seedRecent(app, list(entry("data", "sub", "deep")))
  openDialog(app, "file2")

  expect_equal(recentLabels(app), "data/sub/deep")

  chooseRecent(app, "data/sub/deep")
  expect_equal(unlist(currentLocation(app)), c("", "sub", "deep"))
  expect_true(app$get_js(sprintf(
    "%s.find('.sF-fileList .sF-file-name').filter(function(){ return $(this).text() === 'a.txt'; }).length === 1",
    topModal
  )))
})

test_that("a remembered folder in another root switches the volume", {
  skipUnlessBrowser()
  app <- newApp("recent-file-other-root")
  on.exit(app$stop(), add = TRUE)

  seedRecent(app, list(entry("other", "x")))
  openDialog(app, "file")
  chooseRecent(app, "other/x")

  expect_equal(app$get_js(sprintf("%s.find('.sF-breadcrumps').data('selectedRoot')", topModal)), "other")
  expect_equal(unlist(currentLocation(app)), c("", "x"))
})

test_that("most recent comes first and re-selecting moves an entry to the top", {
  skipUnlessBrowser()
  app <- newApp("recent-order")
  on.exit(app$stop(), add = TRUE)

  seedRecent(app, list(entry("other", "x"), entry("data", "sub", "deep")))
  openDialog(app, "file")
  chooseRecent(app, "data/sub/deep")
  clickFile(app, "a.txt")
  clickSelect(app)

  labels <- vapply(storedRecent(app), function(d) {
    paste(c(d$root, unlist(d$path)), collapse = "/")
  }, character(1))
  expect_equal(labels, c("data/sub/deep", "other/x"))
})

test_that("entries in roots the dialog does not have are hidden", {
  skipUnlessBrowser()
  app <- newApp("recent-root-filter")
  on.exit(app$stop(), add = TRUE)

  seedRecent(app, list(entry("data", "sub"), entry("other", "x")))
  openDialog(app, "onlyOther")

  expect_equal(recentLabels(app), "other/x")
})

test_that("recent = 0 shows no Recent group", {
  skipUnlessBrowser()
  app <- newApp("recent-off")
  on.exit(app$stop(), add = TRUE)

  seedRecent(app, list(entry("data", "sub")))
  openDialog(app, "off")

  expect_equal(app$get_js(sprintf("%s.find('optgroup.sF-recent').length", topModal)), 0)
})

test_that("the directory chooser remembers a selection and can jump back to it", {
  skipUnlessBrowser()
  app <- newApp("recent-dir")
  on.exit(app$stop(), add = TRUE)

  seedRecent(app, list(entry("data", "sub", "deep")))
  openDialog(app, "dir")
  expect_equal(recentLabels(app), "data/sub/deep")

  chooseRecent(app, "data/sub/deep")
  expect_equal(
    app$get_js(sprintf("%s.find('.sF-dirList .selected>.sF-file-name').text()", topModal)),
    "deep"
  )

  clickSelect(app)
  expect_equal(app$get_value(output = "dirpath"), as.character(fs::path(base, "data", "sub", "deep")))
  expect_equal(unlist(storedRecent(app)[[1]]$path), c("sub", "deep"))
})

test_that("saving a file remembers its folder", {
  skipUnlessBrowser()
  app <- newApp("recent-save")
  on.exit(app$stop(), add = TRUE)

  openDialog(app, "save")
  openFolder(app, "sub")
  app$run_js(sprintf("%s.find('.sF-filename').val('out.txt').trigger('input');", topModal))
  clickSelect(app)

  stored <- storedRecent(app)
  expect_equal(stored[[1]]$root, "data")
  expect_equal(unlist(stored[[1]]$path), "sub")
})

test_that("the list survives a page reload", {
  skipUnlessBrowser()
  app <- newApp("recent-reload")
  on.exit(app$stop(), add = TRUE)

  seedRecent(app, list(entry("data", "sub")))
  # A reload through the page drops shinytest2's injected tracer, so
  # wait_for_idle() would fail -- reload through the DevTools protocol and
  # poll for the new Shiny session instead.
  app$get_chromote_session()$Page$reload()
  app$wait_for_js("window.Shiny && Shiny.shinyapp && Shiny.shinyapp.isConnected()", timeout = 20000)
  app$run_js("$('#file').click();")
  app$wait_for_js("$('.sF-modalContainer:visible .sF-breadcrumps option').length > 0", timeout = 20000)

  expect_equal(recentLabels(app), "data/sub")
})

test_that("a corrupt store is ignored rather than breaking the dialog", {
  skipUnlessBrowser()
  app <- newApp("recent-corrupt")
  on.exit(app$stop(), add = TRUE)

  app$run_js("window.localStorage.setItem('shinyFiles-recent:' + window.location.pathname, '{not json');")
  openDialog(app, "file")

  expect_equal(app$get_js(sprintf("%s.find('optgroup.sF-recent').length", topModal)), 0)
  expect_gt(app$get_js(sprintf("%s.find('.sF-fileList .sF-file-name').length", topModal)), 0)
})
