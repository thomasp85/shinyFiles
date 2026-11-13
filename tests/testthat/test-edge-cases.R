# The remaining edge branches of the listing helpers: unnamed roots, missing or
# unreadable locations, and inputs the browser shouldn't send but might.

local({
  base <- tempfile("sf-edges")
  fs::dir_create(fs::path(base, "sub", "inner"))
  fs::file_create(fs::path(base, c("log-1.txt", "log-2.txt", "other.txt")))
  edgeRoot <<- as.character(fs::path_real(base))
})

test_that("every getter rejects unnamed roots", {
  expect_error(fileGetter(roots = unname(edgeRoot))("", NULL), "named vector")
  expect_error(dirGetter(roots = unname(edgeRoot))(list(name = "", expanded = TRUE), NULL), "named vector")
  expect_error(dirCreator(roots = unname(edgeRoot))("x", list(""), NULL), "named vector")
  expect_error(resolveTypedPath(unname(edgeRoot), "sub", NULL), "named vector")
})

test_that("a pattern may be given as a function", {
  get <- fileGetter(roots = c(r = edgeRoot), pattern = function() "^log-")
  expect_setequal(get("", "r")$files$filename, c("log-1.txt", "log-2.txt", "sub"))
})

test_that("an invalid pattern is ignored rather than failing the listing", {
  get <- fileGetter(roots = c(r = edgeRoot), pattern = "[")
  # grepl() still warns about the bad regex; only the listing is under test here.
  l <- suppressWarnings(get("", "r"))
  expect_setequal(l$files$filename, c("log-1.txt", "log-2.txt", "other.txt", "sub"))
})

test_that("fileGetter falls back to the root when the path can't be normalised", {
  local_mocked_bindings(path_norm = function(...) stop("bad path"), .package = "shinyFiles")
  l <- fileGetter(roots = c(r = edgeRoot))("sub", "r")
  expect_equal(as.character(unlist(l$breadcrumps)), "")
  expect_true("sub" %in% l$files$filename)
})

test_that("dirGetter defaults to the first root and walks the tree", {
  l <- dirGetter(roots = c(r = edgeRoot, s = tempdir()))(list(name = "", expanded = TRUE), NULL)
  expect_equal(l$selectedRoot, "r")
  expect_equal(unname(l$rootPath), edgeRoot)
  expect_equal(vapply(l$tree$children, `[[`, "", "name"), "sub")
})

test_that("traverseDirs returns NULL for a folder that is gone", {
  expect_null(traverseDirs(list(name = "missing", expanded = TRUE), edgeRoot, NULL, FALSE))
})

test_that("dirProber has nothing pending without a usable root path", {
  p <- dirProber(roots = c(r = edgeRoot))
  tree <- list(name = "", expanded = TRUE, children = list(list(name = "sub", expanded = FALSE)))
  expect_equal(p$pending(tree, NA, listingCache()), list())
  expect_equal(p$pending(tree, c("a", "b"), listingCache()), list())
  expect_length(p$pending(tree, edgeRoot, listingCache()), 1)
})

test_that("expandedTreeAlong builds the expanded chain to a path", {
  expect_equal(expandedTreeAlong(character(0)), list(name = "", expanded = TRUE, children = list()))
  t <- expandedTreeAlong(c("a", "b"))
  expect_equal(t$children[[1]]$name, "a")
  expect_true(t$children[[1]]$expanded)
  expect_equal(t$children[[1]]$children[[1]]$name, "b")
})

test_that("resolveTypedPath rejects input it can't safely use", {
  roots <- c(r = edgeRoot)
  expect_null(resolveTypedPath(setNames(character(0), character(0)), "x", NULL))
  expect_null(resolveTypedPath(roots, 42, "r"))
  expect_null(resolveTypedPath(roots, c("a", "b"), "r"))
  expect_null(resolveTypedPath(roots, NA_character_, "r"))
  expect_null(resolveTypedPath(roots, strrep("a", 5000), "r"))
  local_mocked_bindings(path_expand = function(...) stop("no"), .package = "shinyFiles")
  expect_null(resolveTypedPath(roots, "~/x", "r"))
})

test_that("resolveTypedPath uses the first root when the current one is unknown", {
  res <- resolveTypedPath(c(r = edgeRoot), "sub", "not-a-root")
  expect_equal(res$root, "r")
  expect_equal(as.character(res$path), "sub")
  expect_equal(resolveTypedPath(c(r = edgeRoot), "   ", NULL), list(root = "r", path = character(0)))
})

test_that("resolveTypedPath copes with a path that can't be normalised", {
  local_mocked_bindings(
    path_real = function(...) stop("nope"),
    path_norm = function(...) stop("nope"),
    .package = "shinyFiles"
  )
  expect_null(resolveTypedPath(c(r = edgeRoot), "sub", "r"))
})

test_that("resolveTypedPath matches a root that doesn't exist on disk lexically", {
  ghost <- file.path(edgeRoot, "ghost-root")
  res <- resolveTypedPath(c(g = ghost), file.path(ghost, "x"), "g")
  expect_equal(res$root, "g")
  expect_equal(as.character(res$path), "x")
})

test_that("a typed path outside every root reports a missing folder in the save dialog", {
  withFileDialog(shinyFileSave, c(r = edgeRoot), function(d) {
    d$open()
    d$type("/no/such/place/at/all")
    expect_false(d$last()$exist)
  })
})
