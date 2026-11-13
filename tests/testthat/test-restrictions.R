# What `restrictions` hides. A restriction names a folder: it hides that folder
# and everything inside it, and nothing that merely shares a prefix or contains
# the same text.

local({
  base <- tempfile("sf-restrict")
  for (d in c("data", "data2", "database", "keep/data", "secret/inner", "mysecret"))
    fs::dir_create(fs::path(base, d))
  fs::file_create(fs::path(base, c("data.txt", "secret/inner/x.txt")))
  restrictBase <<- as.character(fs::path_real(base))
})
rb <- function(...) as.character(fs::path(restrictBase, ...))

test_that("a restriction hides the folder itself and what is inside it", {
  files <- rb(c("data", "data2", "secret", "secret/inner", "secret/inner/x.txt"))
  expect_equal(dropRestricted(files, rb("secret")), rb(c("data", "data2")))
})

test_that("a restriction doesn't hide siblings that share its name as a prefix", {
  files <- rb(c("data", "data2", "database", "data.txt"))
  expect_equal(dropRestricted(files, rb("data")), rb(c("data2", "database", "data.txt")))
})

test_that("a restriction doesn't hide a same-named folder elsewhere", {
  files <- rb(c("data", "keep/data"))
  expect_equal(dropRestricted(files, rb("data")), rb("keep/data"))
})

test_that("a trailing slash on a restriction makes no difference", {
  files <- rb(c("data", "data2"))
  expect_equal(dropRestricted(files, paste0(rb("data"), "/")), rb("data2"))
})

test_that("several restrictions, and none, behave", {
  files <- rb(c("data", "data2", "secret", "mysecret"))
  expect_equal(dropRestricted(files, rb(c("data", "secret"))), rb(c("data2", "mysecret")))
  expect_equal(dropRestricted(files, NULL), files)
  expect_equal(dropRestricted(character(0), rb("data")), character(0))
})

test_that("the dialogs list sibling folders that share a restricted name's prefix", {
  get <- fileGetter(roots = c(r = restrictBase), restrictions = rb("data"))
  expect_setequal(get("", "r")$files$filename, c("data2", "database", "data.txt", "keep", "mysecret", "secret"))
  tree <- dirGetter(roots = c(r = restrictBase), restrictions = rb("data"))(
    list(name = "", expanded = TRUE), "r"
  )$tree
  expect_setequal(vapply(tree$children, `[[`, "", "name"), c("data2", "database", "keep", "mysecret", "secret"))
})
