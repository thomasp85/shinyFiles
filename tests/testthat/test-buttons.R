# Unit tests for the six button/link builders. These only build HTML, so they
# check every argument lands on the attribute the browser reads, and pin the
# full markup with a snapshot so an accidental change shows up in review.

library(htmltools)

# The <button>/<a> itself, without the singleton <head> dependencies.
mainTag <- function(x) x[[2]]
attrOf <- function(x, name) mainTag(x)$attribs[[name]]
classesOf <- function(x) strsplit(attrOf(x, "class"), " ", fixed = TRUE)[[1]]

builders <- list(
  shinyFilesButton = function(...) shinyFilesButton("f", "Pick", "Title", multiple = FALSE, ...),
  shinyFilesLink   = function(...) shinyFilesLink("f", "Pick", "Title", multiple = FALSE, ...),
  shinyDirButton   = function(...) shinyDirButton("f", "Pick", "Title", ...),
  shinyDirLink     = function(...) shinyDirLink("f", "Pick", "Title", ...),
  shinySaveButton  = function(...) shinySaveButton("f", "Pick", "Title", ...),
  shinySaveLink    = function(...) shinySaveLink("f", "Pick", "Title", ...)
)
withView <- c("shinyFilesButton", "shinyFilesLink", "shinySaveButton", "shinySaveLink")
withButtonType <- c("shinyFilesButton", "shinyDirButton", "shinySaveButton")
markerClass <- c(
  shinyFilesButton = "shinyFiles", shinyFilesLink = "shinyFiles",
  shinyDirButton = "shinyDirectories", shinyDirLink = "shinyDirectories",
  shinySaveButton = "shinySave", shinySaveLink = "shinySave"
)

for (nm in names(builders)) {
  make <- builders[[nm]]

  test_that(paste(nm, "renders the attributes the dialog script reads"), {
    x <- make()
    tag <- mainTag(x)
    expect_equal(tag$name, if (grepl("Link$", nm)) "a" else "button")
    expect_equal(attrOf(x, "id"), "f")
    expect_equal(attrOf(x, "type"), "button")
    expect_equal(attrOf(x, "data-title"), "Title")
    # The JS binds dialogs by this class, and Shiny's actionButton binding by
    # action-button; both must be present.
    expect_true(all(c(markerClass[[nm]], "action-button") %in% classesOf(x)))
    expect_match(as.character(x), ">Pick<", fixed = TRUE)
  })

  test_that(paste(nm, "loads the script and stylesheets once per page"), {
    # singleton() content only appears when the page is rendered.
    page <- renderTags(tagList(make(), make()))
    for (asset in c("sF/shinyFiles.js", "sF/styles.css", "sF/fileIcons.css")) {
      expect_equal(lengths(regmatches(page$head, gregexpr(asset, page$head, fixed = TRUE))), 1,
                   label = asset)
    }
  })

  test_that(paste(nm, "adds class, style, icon and extra attributes"), {
    x <- make(class = "my-class", style = "color: red;", icon = shiny::icon("folder"),
              `data-extra` = "yes", onclick = "go()")
    expect_true("my-class" %in% classesOf(x))
    expect_equal(attrOf(x, "style"), "color: red;")
    expect_equal(attrOf(x, "data-extra"), "yes")
    expect_equal(attrOf(x, "onclick"), "go()")
    expect_match(as.character(x), "fa-folder", fixed = TRUE)
  })

  test_that(paste(nm, "restores a bookmarked value into data-val"), {
    expect_null(attrOf(make(), "data-val"))
    restored <- shiny::withReactiveDomain(NULL, {
      shiny:::withRestoreContext(
        shiny:::RestoreContext$new("?_inputs_&f=%22saved%22"),
        make()
      )
    })
    expect_equal(attrOf(restored, "data-val"), "saved")
  })

  test_that(paste(nm, "markup is stable"), {
    expect_snapshot(cat(as.character(make())))
  })
}

for (nm in withButtonType) {
  test_that(paste(nm, "maps buttonType to a Bootstrap class"), {
    expect_true("btn-default" %in% classesOf(builders[[nm]]()))
    x <- builders[[nm]](buttonType = "primary")
    expect_true(all(c("btn", "btn-primary") %in% classesOf(x)))
    expect_false("btn-default" %in% classesOf(x))
  })
}

for (nm in withView) {
  test_that(paste(nm, "accepts each viewtype and falls back to detail"), {
    for (vt in c("detail", "list", "icon")) {
      expect_equal(attrOf(builders[[nm]](viewtype = vt), "data-view"), paste0("sF-btn-", vt))
    }
    expect_equal(attrOf(builders[[nm]](), "data-view"), "sF-btn-detail")
    for (bad in list("grid", character(0), NULL, NA_character_)) {
      expect_equal(attrOf(builders[[nm]](viewtype = bad), "data-view"), "sF-btn-detail")
    }
  })
}

test_that("folder buttons don't carry a view, select or file type", {
  for (nm in c("shinyDirButton", "shinyDirLink")) {
    x <- builders[[nm]]()
    expect_null(attrOf(x, "data-view"))
    expect_null(attrOf(x, "data-selecttype"))
    expect_null(attrOf(x, "data-filetype"))
  }
})

test_that("shinyDirButton coerces a non-character label", {
  expect_match(as.character(shinyDirButton("d", 42, "T")), ">42<", fixed = TRUE)
  expect_match(as.character(shinyDirLink("d", 42, "T")), ">42<", fixed = TRUE)
})

test_that("file buttons set single or multiple selection", {
  for (make in list(shinyFilesButton, shinyFilesLink)) {
    expect_equal(attrOf(make("f", "L", "T", multiple = FALSE), "data-selecttype"), "single")
    expect_equal(attrOf(make("f", "L", "T", multiple = TRUE), "data-selecttype"), "multiple")
  }
})

test_that("file buttons require multiple", {
  expect_error(as.character(shinyFilesButton("f", "L", "T")), "multiple")
  expect_error(as.character(shinyFilesLink("f", "L", "T")), "multiple")
})

test_that("save buttons carry the filename and file types as JSON", {
  for (make in list(shinySaveButton, shinySaveLink)) {
    x <- make("s", "L", "T")
    expect_equal(attrOf(x, "data-filename"), "")
    expect_equal(as.character(attrOf(x, "data-filetype")), "[null]")

    x <- make("s", "L", "T", filename = "report",
              filetype = list(text = "txt", picture = c("jpeg", "jpg")))
    expect_equal(attrOf(x, "data-filename"), "report")
    # `name` is a one-element array; the dialog only ever renders it as text.
    expect_equal(
      as.character(attrOf(x, "data-filetype")),
      '[{"name":["text"],"ext":["txt"]},{"name":["picture"],"ext":["jpeg","jpg"]}]'
    )
  }
})
