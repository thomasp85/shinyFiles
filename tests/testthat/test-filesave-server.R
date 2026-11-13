# Server-side tests for shinyFileSave(), driven through testServer() with the
# harness in helper-dialog.R.

makeSaveTree <- function() {
  base <- tempfile("sf-save")
  fs::dir_create(fs::path(base, "out", "deep"))
  fs::file_create(fs::path(base, c("existing.txt", "data.csv")))
  as.character(fs::path_real(base))
}

test_that("opening lists the first root as a save message", {
  withFileDialog(shinyFileSave, c(r = makeSaveTree()), function(d) {
    expect_null(d$last())
    d$open()
    expect_equal(d$messages(), "shinySave")
    expect_equal(filenames(d$last()), c("data.csv", "existing.txt", "out"))
    expect_true(d$last()$exist)
    expect_equal(d$last()$recentLimit, 10)
  })
})

test_that("defaultRoot and defaultPath choose where the dialog opens", {
  withFileDialog(shinyFileSave, c(other = tempdir(), r = makeSaveTree()), function(d) {
    d$open()
    expect_equal(d$last()$root, "r")
    expect_equal(crumbs(d$last()), c("", "out"))
  }, defaultRoot = "r", defaultPath = "out")
})

test_that("navigating lists the folder", {
  withFileDialog(shinyFileSave, c(r = makeSaveTree()), function(d) {
    d$open()
    d$go(c("out", "deep"))
    expect_equal(crumbs(d$last()), c("", "out", "deep"))
    expect_true(d$last()$exist)
  })
})

test_that("a path whose last part doesn't exist opens the parent with that filename", {
  withFileDialog(shinyFileSave, c(r = makeSaveTree()), function(d) {
    d$open()
    d$go(c("out", "newfile.txt"))
    expect_true(d$last()$exist)
    expect_equal(crumbs(d$last()), c("", "out"))
    expect_equal(d$last()$selectedFile, "newfile.txt")
  })
})

test_that("a missing folder two levels down is reported as missing", {
  withFileDialog(shinyFileSave, c(r = makeSaveTree()), function(d) {
    d$open()
    before <- d$last()
    d$go(c("nope", "also-nope", "file.txt"))
    expect_false(d$last()$exist)
    # The dialog keeps showing the folder it was in.
    expect_equal(filenames(d$last()), filenames(before))
  })
})

test_that("typed paths resolve against the roots", {
  base <- makeSaveTree()
  withFileDialog(shinyFileSave, c(r = base), function(d) {
    d$open()
    d$type(file.path(base, "out"))
    expect_equal(crumbs(d$last()), c("", "out"))

    d$type(file.path(base, "out", "brand-new.csv"))
    expect_equal(crumbs(d$last()), c("", "out"))
    expect_equal(d$last()$selectedFile, "brand-new.csv")
  })
})

test_that("a typed relative path is taken from the current root", {
  withFileDialog(shinyFileSave, c(r = makeSaveTree()), function(d) {
    d$open()
    d$type("out/deep")
    expect_equal(crumbs(d$last()), c("", "out", "deep"))
  })
})

test_that("the new-folder button creates the folder and lists it", {
  base <- makeSaveTree()
  withFileDialog(shinyFileSave, c(r = base), function(d) {
    d$open()
    d$newDir("made", path = "out")
    d$go("out")
    expect_true(dir.exists(file.path(base, "out", "made")))
    expect_true("made" %in% filenames(d$last()))
    expect_length(d$notifications(), 0)
  })
})

test_that("the new-folder button is refused when allowDirCreate is FALSE", {
  base <- makeSaveTree()
  withFileDialog(shinyFileSave, c(r = base), function(d) {
    d$open()
    d$newDir("blocked")
    expect_false(dir.exists(file.path(base, "blocked")))
    notes <- d$notifications()
    expect_length(notes, 1)
    expect_match(notes[[1]]$text, "disabled")
    expect_equal(notes[[1]]$type, "error")
  }, allowDirCreate = FALSE)
})

test_that("the same new-folder request is only handled once", {
  base <- makeSaveTree()
  withFileDialog(shinyFileSave, c(r = base), function(d) {
    d$open()
    d$newDir("once")
    fs::dir_delete(fs::path(base, "once"))
    # Navigating re-runs the observer with the same newDir input still set.
    d$go("out")
    expect_false(dir.exists(file.path(base, "once")))
  })
})

test_that("refresh resends the listing as a refresh message", {
  base <- makeSaveTree()
  withFileDialog(shinyFileSave, c(r = base), function(d) {
    d$open()
    fs::file_create(fs::path(base, "appeared.txt"))
    d$refresh()
    expect_equal(tail(d$messages(), 1), "shinySave-refresh")
    expect_true("appeared.txt" %in% filenames(d$last()))
  })
})

test_that("updateFreq re-reads the folder on a timer", {
  base <- makeSaveTree()
  withFileDialog(shinyFileSave, c(r = base), function(d) {
    d$open()
    n <- length(d$messages())
    fs::file_create(fs::path(base, "ticked.txt"))
    d$elapse(600)
    expect_gt(length(d$messages()), n)
    expect_true("ticked.txt" %in% filenames(d$last()))
  }, updateFreq = 500)
})

test_that("filetypes filters the save listing", {
  withFileDialog(shinyFileSave, c(r = makeSaveTree()), function(d) {
    d$open()
    expect_equal(filenames(d$last()), c("data.csv", "out"))
  }, filetypes = "csv")
})

test_that("recent is passed to the browser", {
  withFileDialog(shinyFileSave, c(r = makeSaveTree()), function(d) {
    d$open()
    expect_equal(d$last()$recentLimit, 3)
  }, recent = 3)
})
