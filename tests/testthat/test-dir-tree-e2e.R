# End-to-end tests for the folder chooser's expand arrows.
#
# Collapsed folders are drawn with an arrow before they have been looked
# inside, then the server checks them in the background and the arrows on
# empty ones go away. "deep" holds only a file, so it has no subfolders.

library(shinytest2)

appDir <- local({
  dir <- fs::path(tempfile("sf-tree-e2e"))
  fs::dir_create(fs::path(dir, "data", "sub", "deep"))
  fs::file_create(fs::path(dir, "data", "sub", "deep", "a.txt"))
  fs::dir_create(fs::path(dir, "other", "x"))

  writeLines(
    c(
      'library(shiny)',
      shinyFilesLoadLine(),
      'base <- Sys.getenv("SF_TREE_E2E_BASE")',
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

withr::local_envvar(c(SF_TREE_E2E_BASE = base), .local_envir = teardown_env())

# --- helpers ----------------------------------------------------------------

newApp <- function(name) {
  app <- AppDriver$new(appDir, name = name, load_timeout = 30000)
  # Every AppDriver gets a fresh Chrome profile, but be explicit about it.
  app$run_js("window.localStorage.clear();")
  app
}

openDialog <- function(app, id) {
  openDialogFor(app, id)
}

topModal <- "$('.sF-modalContainer:visible').last()"

nodeFor <- function(name) sprintf(
  "%s.find('.sF-dirList .sF-directory').filter(function(){ return $(this).children('.sF-file-name').text() === '%s'; })",
  topModal, name
)

expandNode <- function(app, name) {
  app$run_js(sprintf("%s.children('.sF-expander').children('span').click();", nodeFor(name)))
  app$wait_for_idle()
}

test_that("arrows on empty folders clear on their own, without a click", {
  skipUnlessBrowser()
  app <- newApp("tree-empty-arrow-auto")
  on.exit(app$stop(), add = TRUE)

  openDialog(app, "dir")
  expandNode(app, "sub")
  app$wait_for_js(sprintf("%s.hasClass('empty')", nodeFor("deep")), timeout = 10000)
  expect_equal(app$get_js(sprintf("%s.children('.sF-expander').css('visibility')", nodeFor("deep"))), "hidden")
  expect_false(app$get_js(sprintf("%s.hasClass('expanded')", nodeFor("deep"))))
  # A folder with subfolders keeps its arrow.
  expect_false(app$get_js(sprintf("%s.hasClass('empty')", nodeFor("sub"))))
})

test_that("an empty folder found in the background stays marked after other clicks", {
  skipUnlessBrowser()
  app <- newApp("tree-empty-arrow-sticky")
  on.exit(app$stop(), add = TRUE)

  openDialog(app, "dir")
  expandNode(app, "sub")
  app$wait_for_js(sprintf("%s.hasClass('empty')", nodeFor("deep")), timeout = 10000)
  # Any click resends the client's tree; the mark must survive the round trip.
  app$run_js(sprintf("%s.children('.sF-file-name').click();", nodeFor("sub")))
  app$wait_for_idle()
  expect_true(app$get_js(sprintf("%s.hasClass('empty')", nodeFor("deep"))))
})

test_that("expanding a folder with no subfolders clears its expand arrow", {
  skipUnlessBrowser()
  app <- newApp("tree-empty-arrow")
  on.exit(app$stop(), add = TRUE)

  openDialog(app, "dir")
  expandNode(app, "sub")
  # Expand before the background check could report it.
  expandNode(app, "deep")
  expect_true(app$get_js(sprintf("%s.hasClass('empty')", nodeFor("deep"))))
  expect_false(app$get_js(sprintf("%s.hasClass('expanded')", nodeFor("deep"))))
  expect_equal(app$get_js(sprintf("%s.children('.sF-expander').css('visibility')", nodeFor("deep"))), "hidden")
})
