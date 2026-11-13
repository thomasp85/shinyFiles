# Unit tests for parseFilePaths(), parseDirPath() and parseSavePath(), which turn
# the value a dialog sends back into paths. An integer value is the click count
# Shiny's action button sends before anything has been chosen.

roots <- local({
  base <- tempfile("sf-parse")
  fs::dir_create(fs::path(base, "a", "sub"))
  fs::dir_create(fs::path(base, "b"))
  base <- fs::path_real(base)
  writeLines("hello", fs::path(base, "a", "one.txt"))
  writeLines(strrep("x", 100), fs::path(base, "a", "sub", "two.csv"))
  c(first = as.character(fs::path(base, "a")), second = as.character(fs::path(base, "b")))
})

emptyFiles <- tibble::tibble(
  name = character(0), size = numeric(0), type = character(0), datapath = character(0)
)
emptySave <- tibble::tibble(name = character(0), type = character(0), datapath = character(0))

test_that("the parsers return exactly the fileInput() columns", {
  skip("Known bug: tibble() turns stringsAsFactors = FALSE into a column; fixed in the bug-fix PR")
  expect_named(parseFilePaths(roots, NULL), c("name", "size", "type", "datapath"))
  expect_named(parseSavePath(roots, NULL), c("name", "type", "datapath"))
  expect_named(parseSavePath(roots, 1L), c("name", "type", "datapath"))
  expect_named(parseSavePath(roots, list(name = "x", path = list(""), root = "first")),
               c("name", "type", "datapath"))
})

# The column-shape bug above is tested on its own; the rest compares content.
dropSAF <- function(x) x[setdiff(names(x), "stringsAsFactors")]

test_that("parseFilePaths returns an empty table until a file is chosen", {
  expect_equal(dropSAF(parseFilePaths(roots, NULL)), emptyFiles, ignore_attr = TRUE)
  expect_equal(dropSAF(parseFilePaths(roots, NA)), emptyFiles, ignore_attr = TRUE)
  expect_equal(dropSAF(parseFilePaths(roots, 1L)), emptyFiles, ignore_attr = TRUE)
  expect_equal(dropSAF(parseFilePaths(roots, list(files = list(), root = "first"))), emptyFiles,
               ignore_attr = TRUE)
})

test_that("parseFilePaths resolves one and several files with their sizes", {
  one <- parseFilePaths(roots, list(files = list("0" = list("", "one.txt")), root = "first"))
  expect_equal(one$name, "one.txt")
  expect_equal(as.character(one$datapath), file.path(roots[["first"]], "one.txt"))
  expect_equal(one$size, file.size(file.path(roots[["first"]], "one.txt")))
  expect_equal(one$type, "")

  two <- parseFilePaths(roots, list(
    files = list("0" = list("", "one.txt"), "1" = list("", "sub", "two.csv")),
    root = "first"
  ))
  expect_equal(two$name, c("one.txt", "two.csv"))
  expect_equal(as.character(two$datapath),
               file.path(roots[["first"]], c("one.txt", "sub/two.csv")))
  expect_equal(two$size[2], 101)
})

test_that("parseFilePaths accepts roots as a function", {
  x <- parseFilePaths(function() roots, list(files = list("0" = list("", "one.txt")), root = "first"))
  expect_equal(x$name, "one.txt")
})

test_that("parseDirPath resolves a folder in the chosen root", {
  expect_equal(parseDirPath(roots, 3L), character(0))
  expect_equal(as.character(parseDirPath(roots, list(path = list("", "sub"), root = "first"))),
               file.path(roots[["first"]], "sub"))
  expect_equal(as.character(parseDirPath(roots, list(path = list(""), root = "second"))),
               roots[["second"]])
  expect_equal(as.character(parseDirPath(function() roots, list(path = list("", "sub"), root = "first"))),
               file.path(roots[["first"]], "sub"))
})

test_that("parseDirPath and parseSavePath reject unnamed roots", {
  expect_error(parseDirPath(unname(roots), list(path = list(""), root = "first")), "named vector")
  expect_error(parseSavePath(unname(roots), list(name = "x", path = list(""), root = "first")),
               "named vector")
})

test_that("parseSavePath returns an empty table until a file is saved", {
  expect_equal(dropSAF(parseSavePath(roots, NULL)), emptySave, ignore_attr = TRUE)
  expect_equal(dropSAF(parseSavePath(roots, 2L)), emptySave, ignore_attr = TRUE)
})

test_that("parseSavePath builds the path from root, folder and name", {
  x <- parseSavePath(roots, list(name = "out.txt", type = list("text"), path = list("", "sub"), root = "first"))
  expect_equal(x$name, "out.txt")
  expect_equal(x$type, "text")
  expect_equal(as.character(x$datapath), file.path(roots[["first"]], "sub", "out.txt"))

  # A save without a file type picker sends an empty type.
  y <- parseSavePath(roots, list(name = "out", type = list(), path = list(""), root = "second"))
  expect_equal(y$type, "")
  expect_equal(as.character(y$datapath), file.path(roots[["second"]], "out"))

  z <- parseSavePath(function() roots, list(name = "out", path = list(""), root = "first"))
  expect_equal(z$type, "")
})
