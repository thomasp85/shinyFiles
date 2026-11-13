# One app for the input catalogue tests (test-catalogue-*.R). Every dialog
# type, plus variants for the arguments that change what is rendered.

catalogueTree <- function() {
  base <- tempfile("sf-catalogue")
  dir.create(base)
  base <- normalizePath(base)
  dir.create(file.path(base, "data", "folder", "sub"), recursive = TRUE)
  dir.create(file.path(base, "data", "empty"))
  dir.create(file.path(base, "data", "locked"))
  dir.create(file.path(base, "other", "elsewhere"), recursive = TRUE)
  # Several sizes and extensions so every sort order is distinguishable, and
  # more than ten files so range selection crosses into two-digit indices.
  sizes <- c(a.txt = 30, b.csv = 10, c.R = 20)
  for (f in names(sizes)) writeLines(strrep("x", sizes[[f]]), file.path(base, "data", f))
  for (i in sprintf("%02d", 1:12)) file.create(file.path(base, "data", "folder", paste0("f", i, ".txt")))
  Sys.chmod(file.path(base, "data", "locked"), "555")
  base
}

catalogueAppLines <- c(
  'base <- Sys.getenv("SF_CATALOGUE_BASE")',
  'roots <- c(data = file.path(base, "data"), other = file.path(base, "other"))',
  'ui <- fluidPage(',
  '  shinyFilesButton("file", "File", "Pick files", multiple = TRUE),',
  '  shinyFilesButton("fileIcon", "File (icon view)", "Pick", multiple = FALSE, viewtype = "icon"),',
  '  shinyDirButton("dir", "Folder", "Pick a folder"),',
  '  shinyDirButton("dirNoCreate", "Folder (no create)", "Pick a folder"),',
  '  shinySaveButton("save", "Save", "Save as", filename = "report",',
  '                  filetype = list(text = "txt", csv = "csv")),',
  '  shinySaveButton("saveOne", "Save (one type)", "Save as", filetype = list(R = "R")),',
  '  verbatimTextOutput("fileOut"), verbatimTextOutput("dirOut"),',
  '  verbatimTextOutput("saveOut")',
  ')',
  'server <- function(input, output, session) {',
  '  shinyFileChoose(input, "file", roots = roots)',
  '  shinyFileChoose(input, "fileIcon", roots = roots)',
  '  shinyDirChoose(input, "dir", roots = roots)',
  '  shinyDirChoose(input, "dirNoCreate", roots = roots, allowDirCreate = FALSE)',
  '  shinyFileSave(input, "save", roots = roots)',
  '  shinyFileSave(input, "saveOne", roots = roots)',
  '  output$fileOut <- renderText({ req(input$file);',
  '    paste(parseFilePaths(roots, input$file)$datapath, collapse = "|") })',
  '  output$dirOut <- renderText({ req(input$dir);',
  '    as.character(parseDirPath(roots, input$dir)) })',
  '  output$saveOut <- renderText({ req(input$save);',
  '    p <- parseSavePath(roots, input$save); paste(p$datapath, p$type) })',
  '}',
  'shinyApp(ui, server)'
)

readCatalogue <- function() {
  path <- testthat::test_path("inputs-catalogue.csv")
  utils::read.csv(path, stringsAsFactors = FALSE, na.strings = character(0))
}

# The topmost open dialog, as a jQuery expression.
topModal <- "$('.sF-modalContainer:visible').last()"

openDialog <- function(app, id) {
  app$click(id)
  waitForSelector(app, ".sF-modalContainer.in .sF-responseButtons")
  # The listing arrives after the dialog is drawn.
  app$wait_for_js(sprintf("%s.data('currentData') !== undefined", topModal))
  invisible(app)
}

closeDialogs <- function(app) {
  app$run_js(sprintf("%s.find('#sF-cancelButton').trigger('click')", topModal))
  app$wait_for_js("$('.sF-modalContainer').length === 0")
}

jsString <- function(x) jsonlite::toJSON(x, auto_unbox = TRUE)
