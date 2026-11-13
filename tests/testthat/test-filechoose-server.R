# Server-side tests for shinyFileChoose(), driven through testServer() with the
# harness in helper-dialog.R.

makeFileTree <- function() {
  base <- tempfile("sf-choose")
  fs::dir_create(fs::path(base, "docs", "old"))
  fs::dir_create(fs::path(base, "pics"))
  fs::file_create(fs::path(base, c("a.txt", "b.csv", "c.R", "noext")))
  fs::file_create(fs::path(base, "docs", c("report.txt", "notes.md")))
  fs::file_create(fs::path(base, "pics", "cat.png"))
  as.character(fs::path_real(base))
}

test_that("nothing is sent until the dialog is opened", {
  withFileDialog(shinyFileChoose, c(r = makeFileTree()), function(d) {
    expect_null(d$last())
    d$open()
    expect_equal(d$messages(), "shinyFiles")
  })
})

test_that("opening lists the first root", {
  base <- makeFileTree()
  withFileDialog(shinyFileChoose, c(r = base, other = tempdir()), function(d) {
    d$open()
    l <- d$last()
    expect_equal(l$root, "r")
    expect_equal(unlist(l$roots), c("r", "other"))
    expect_equal(filenames(l), sort(c("a.txt", "b.csv", "c.R", "docs", "noext", "pics")))
    expect_true(l$exist)
    expect_true(l$writable)
    expect_equal(crumbs(l), "")
    expect_equal(l$recentLimit, 10)
  })
})

test_that("defaultRoot and defaultPath choose where the dialog opens", {
  base <- makeFileTree()
  withFileDialog(shinyFileChoose, c(other = tempdir(), r = base), function(d) {
    d$open()
    expect_equal(d$last()$root, "r")
    expect_equal(crumbs(d$last()), c("", "docs"))
    expect_equal(filenames(d$last()), c("notes.md", "old", "report.txt"))
  }, defaultRoot = "r", defaultPath = "docs")
})

test_that("navigating lists the folder and its breadcrumbs", {
  withFileDialog(shinyFileChoose, c(r = makeFileTree()), function(d) {
    d$open()
    d$go("docs")
    expect_equal(crumbs(d$last()), c("", "docs"))
    d$go(c("docs", "old"))
    expect_equal(crumbs(d$last()), c("", "docs", "old"))
    expect_length(filenames(d$last()), 0)
  })
})

test_that("filetypes keeps folders and only the matching files", {
  withFileDialog(shinyFileChoose, c(r = makeFileTree()), function(d) {
    d$open()
    expect_equal(filenames(d$last()), c("a.txt", "c.R", "docs", "pics"))
  }, filetypes = c("txt", "r"))
})

test_that("pattern filters files by regular expression", {
  withFileDialog(shinyFileChoose, c(r = makeFileTree()), function(d) {
    d$open()
    expect_equal(filenames(d$last()), c("b.csv", "docs", "pics"))
  }, pattern = "^b")
})

test_that("filetypes and pattern may be reactive", {
  ft <- reactiveVal("csv")
  withFileDialog(shinyFileChoose, c(r = makeFileTree()), function(d) {
    d$open()
    expect_equal(filenames(d$last()), c("b.csv", "docs", "pics"))
    ft("txt")
    d$refresh()
    expect_equal(filenames(d$last()), c("a.txt", "docs", "pics"))
  }, filetypes = ft)
})

test_that("typed paths go to the matching root, or report a missing folder", {
  base <- makeFileTree()
  withFileDialog(shinyFileChoose, c(r = base), function(d) {
    d$open()
    d$type(file.path(base, "docs"))
    expect_equal(crumbs(d$last()), c("", "docs"))
    expect_true(d$last()$exist)

    d$type("/definitely/not/under/the/root")
    expect_equal(d$last()$root, "r")
    expect_false(d$last()$exist)
  })
})

test_that("a typed path naming a file opens its folder with it selected", {
  base <- makeFileTree()
  withFileDialog(shinyFileChoose, c(r = base), function(d) {
    d$open()
    d$type(file.path(base, "docs", "report.txt"))
    expect_equal(crumbs(d$last()), c("", "docs"))
    expect_equal(d$last()$selectedFile, "report.txt")
  })
})

test_that("a path that escapes the root stays at the root", {
  withFileDialog(shinyFileChoose, c(r = makeFileTree()), function(d) {
    d$open()
    d$go(c("..", "..", ".."))
    expect_equal(crumbs(d$last()), "")
    expect_true("a.txt" %in% filenames(d$last()))
  })
})

test_that("refresh resends the listing as a refresh message", {
  base <- makeFileTree()
  withFileDialog(shinyFileChoose, c(r = base), function(d) {
    d$open()
    fs::file_create(fs::path(base, "new.txt"))
    d$refresh()
    expect_equal(tail(d$messages(), 1), "shinyFiles-refresh")
    expect_true("new.txt" %in% filenames(d$last()))
  })
})

test_that("updateFreq re-reads the folder on a timer", {
  base <- makeFileTree()
  withFileDialog(shinyFileChoose, c(r = base), function(d) {
    d$open()
    n <- length(d$messages())
    fs::file_create(fs::path(base, "later.txt"))
    d$elapse(1100)
    expect_gt(length(d$messages()), n)
    expect_true("later.txt" %in% filenames(d$last()))
  }, updateFreq = 1000)
})

test_that("recent is passed to the browser", {
  withFileDialog(shinyFileChoose, c(r = makeFileTree()), function(d) {
    d$open()
    expect_equal(d$last()$recentLimit, 0)
  }, recent = 0)
})

test_that("roots may be a function", {
  base <- makeFileTree()
  withFileDialog(shinyFileChoose, function() c(r = base), function(d) {
    d$open()
    expect_true("a.txt" %in% filenames(d$last()))
  })
})

test_that("works inside a module, under the namespaced id", {
  base <- makeFileTree()
  sent <- NULL
  server <- function(input, output, session) {
    session$sendCustomMessage <- function(type, message) sent <<- message
    moduleServer("m", function(input, output, session) {
      shinyFileChoose(input, "f", roots = c(r = base), session = session)
    })
  }
  testServer(server, {
    session$setInputs(`m-f` = 1)
    expect_equal(sent$id, "m-f")
    expect_true("a.txt" %in% filenames(roundTrip(sent$dir)))
  })
})
