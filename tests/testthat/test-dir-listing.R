# Adversarial tests for the server-side listings behind the dialogs.
#
# The folder chooser was slow on NFS because building the tree (a) listed the
# inside of every *collapsed* subfolder just to learn whether to draw an expand
# arrow, and (b) stat'ed every entry a second time with dir.exists() to find
# the folders. These tests pin what the listings must still return -- the
# folder set, symlink handling, restrictions, hidden entries -- and the cost
# contract that a collapsed folder is never listed. The per-entry lookups in
# (b) are counted by bench/strace-count.sh rather than here, since base
# functions cannot be mocked.
#
# The correctness expectations are checked against an independent oracle
# (base list.files() + dir.exists()), not against the implementation.

skip_on_os("windows") # symlinks and chmod below

fixture <- local({
  base <- fs::path(tempfile("sf-listing"))
  fs::dir_create(base)

  fs::dir_create(fs::path(base, "full", c("a", "b")))
  fs::file_create(fs::path(base, "full", "inside.txt"))
  fs::dir_create(fs::path(base, "full", "a", "deeper"))
  fs::dir_create(fs::path(base, "emptyFolder"))
  fs::dir_create(fs::path(base, "onlyFiles"))
  fs::file_create(fs::path(base, "onlyFiles", c("x.txt", "y.csv")))
  fs::dir_create(fs::path(base, ".hiddenFolder", "child"))
  fs::dir_create(fs::path(base, "secret", "child"))
  fs::dir_create(fs::path(base, "full", "secret_nested"))

  # Names that break naive string handling: whitespace, glob and regex
  # metacharacters, a leading dash, non-ASCII.
  odd <- c("with space", "[brackets]", "star*", "paren(", "-dash", "ünicode", "dot.ted")
  fs::dir_create(fs::path(base, odd))

  fs::file_create(fs::path(base, c("top.txt", "noext", ".hiddenFile")))
  # A file whose name looks like a folder.
  fs::file_create(fs::path(base, "looksLikeAFolder"))

  fs::link_create(fs::path(base, "full"), fs::path(base, "linkToDir"))
  fs::link_create(fs::path(base, "top.txt"), fs::path(base, "linkToFile"))
  fs::link_create(fs::path(base, "doesNotExist"), fs::path(base, "brokenLink"))
  # Points at its own parent: walking it unguarded never terminates.
  fs::link_create(base, fs::path(base, "full", "loop"))

  fs::dir_create(fs::path(base, "locked", "child"))
  Sys.chmod(fs::path(base, "locked"), "000")

  as.character(fs::path_real(base))
})
withr::defer(
  {
    Sys.chmod(fs::path(fixture, "locked"), "755")
    fs::dir_delete(fixture)
  },
  envir = teardown_env()
)

roots <- c(fx = fixture)

# Running as root ignores permission bits, so "locked" is readable there.
lockedIsLocked <- function() {
  inherits(try(list.files(fs::path(fixture, "locked")), silent = TRUE), "try-error") ||
    length(list.files(fs::path(fixture, "locked"))) == 0
}

# --- oracle -----------------------------------------------------------------

oracleFolders <- function(dir, hidden = FALSE, restrictions = NULL) {
  entries <- list.files(dir, all.files = hidden, full.names = TRUE, no.. = TRUE)
  if (!is.null(restrictions)) {
    # A restriction names a folder: it hides that folder and what's inside it.
    entries <- entries[!vapply(entries, function(e) {
      any(e == restrictions | startsWith(e, paste0(restrictions, "/")))
    }, logical(1))]
  }
  sort(basename(entries[dir.exists(entries)]))
}

childNames <- function(node) {
  sort(vapply(node$children, `[[`, character(1), "name"))
}

findChild <- function(node, name) {
  Filter(function(ch) identical(ch$name, name), node$children)[[1]]
}

openTree <- function(...) {
  dirGetter(roots = roots, ...)(tree = list(name = "", expanded = TRUE), root = "fx")$tree
}

# --- folder tree: what it lists ---------------------------------------------

test_that("the tree lists exactly the folders an independent listing finds", {
  tree <- openTree()
  expect_equal(childNames(tree), oracleFolders(fixture))
})

test_that("a symlink to a folder is listed as a folder", {
  expect_true("linkToDir" %in% childNames(openTree()))
})

test_that("symlinks to files, broken symlinks and plain files are not folders", {
  names <- childNames(openTree())
  expect_false("linkToFile" %in% names)
  expect_false("brokenLink" %in% names)
  expect_false("top.txt" %in% names)
  expect_false("looksLikeAFolder" %in% names)
})

test_that("odd folder names survive listing unchanged", {
  names <- childNames(openTree())
  for (n in c("with space", "[brackets]", "star*", "paren(", "-dash", "ünicode", "dot.ted")) {
    expect_true(n %in% names, info = n)
  }
})

test_that("hidden folders follow the hidden flag", {
  expect_false(".hiddenFolder" %in% childNames(openTree()))
  expect_true(".hiddenFolder" %in% childNames(openTree(hidden = TRUE)))
  expect_equal(childNames(openTree(hidden = TRUE)), oracleFolders(fixture, hidden = TRUE))
})

test_that("restrictions hide folders at the top and at nested levels", {
  restrictions <- as.character(c(fs::path(fixture, "secret"), fs::path(fixture, "full", "secret_nested")))
  dg <- dirGetter(roots = roots, restrictions = restrictions)
  tree <- dg(
    tree = list(name = "", expanded = TRUE, children = list(
      list(name = "full", expanded = TRUE, children = list())
    )),
    root = "fx"
  )$tree
  expect_equal(childNames(tree), oracleFolders(fixture, restrictions = restrictions))
  expect_false("secret" %in% childNames(tree))
  full <- findChild(tree, "full")
  expect_equal(childNames(full), oracleFolders(fs::path(fixture, "full"), restrictions = restrictions))
  expect_false("secret_nested" %in% childNames(full))
})

test_that("an expanded folder is walked and its children reported", {
  dg <- dirGetter(roots = roots)
  tree <- dg(
    tree = list(name = "", expanded = TRUE, children = list(
      list(name = "full", expanded = TRUE, children = list())
    )),
    root = "fx"
  )$tree
  full <- findChild(tree, "full")
  expect_true(full$expanded)
  expect_false(full$empty)
  expect_equal(childNames(full), oracleFolders(fs::path(fixture, "full")))
})

test_that("an expanded folder with no subfolders is marked empty and collapsed", {
  for (name in c("emptyFolder", "onlyFiles")) {
    dg <- dirGetter(roots = roots)
    tree <- dg(
      tree = list(name = "", expanded = TRUE, children = list(
        list(name = name, expanded = TRUE, children = list())
      )),
      root = "fx"
    )$tree
    node <- findChild(tree, name)
    expect_true(node$empty, info = name)
    expect_false(node$expanded, info = name)
    expect_length(node$children, 0)
  }
})

test_that("a symlink loop is listed but never walked unless expanded", {
  dg <- dirGetter(roots = roots)
  tree <- dg(
    tree = list(name = "", expanded = TRUE, children = list(
      list(name = "full", expanded = TRUE, children = list())
    )),
    root = "fx"
  )$tree
  loop <- findChild(findChild(tree, "full"), "loop")
  expect_false(loop$expanded)
  expect_length(loop$children, 0)
})

test_that("an unreadable folder is listed and expanding it does not error", {
  skip_if_not(lockedIsLocked(), "running with permissions that ignore chmod")
  expect_true("locked" %in% childNames(openTree()))
  dg <- dirGetter(roots = roots)
  tree <- expect_no_error(dg(
    tree = list(name = "", expanded = TRUE, children = list(
      list(name = "locked", expanded = TRUE, children = list())
    )),
    root = "fx"
  )$tree)
  locked <- findChild(tree, "locked")
  expect_length(locked$children, 0)
})

test_that("a folder that vanished between requests is dropped, not an error", {
  gone <- fs::path(fixture, "vanishing")
  fs::dir_create(fs::path(gone, "child"))
  dg <- dirGetter(roots = roots)
  stale <- list(name = "", expanded = TRUE, children = list(
    list(name = "vanishing", expanded = TRUE, children = list(
      list(name = "child", expanded = TRUE, children = list())
    ))
  ))
  fs::dir_delete(gone)
  tree <- expect_no_error(dg(tree = stale, root = "fx")$tree)
  expect_false("vanishing" %in% childNames(tree))
})

test_that("a folder replaced by a file between requests is dropped", {
  p <- fs::path(fixture, "becomesFile")
  fs::dir_create(p)
  dg <- dirGetter(roots = roots)
  stale <- list(name = "", expanded = TRUE, children = list(
    list(name = "becomesFile", expanded = TRUE, children = list())
  ))
  fs::dir_delete(p)
  fs::file_create(p)
  on.exit(fs::file_delete(p))
  tree <- dg(tree = stale, root = "fx")$tree
  expect_false("becomesFile" %in% childNames(tree))
})

# --- folder tree: what it costs ---------------------------------------------

# Counts every directory listing the tree makes, by wrapping fs::dir_ls as
# imported into shinyFiles.
countListings <- function(expr) {
  listed <- character(0)
  realDirLs <- fs::dir_ls
  local_mocked_bindings(
    dir_ls = function(path = ".", ...) {
      listed <<- c(listed, as.character(path))
      realDirLs(path, ...)
    },
    .package = "shinyFiles"
  )
  force(expr)
  basename(listed)
}

test_that("opening the tree lists only the root, not every collapsed subfolder", {
  listed <- countListings(openTree())
  expect_equal(listed, basename(fixture))
})

test_that("each expanded folder is listed exactly once and collapsed siblings never", {
  dg <- dirGetter(roots = roots)
  listed <- countListings(dg(
    tree = list(name = "", expanded = TRUE, children = list(
      list(name = "full", expanded = TRUE, children = list(
        list(name = "a", expanded = TRUE, children = list())
      ))
    )),
    root = "fx"
  ))
  expect_setequal(listed, c(basename(fixture), "full", "a"))
  expect_equal(anyDuplicated(listed), 0L)
})

test_that("a collapsed folder is offered as expandable without being listed", {
  # Whether it is empty is only known once it is listed, so until then it is
  # shown as expandable; expanding an empty one then clears the arrow.
  tree <- openTree()
  for (name in c("emptyFolder", "onlyFiles", "full")) {
    node <- findChild(tree, name)
    expect_false(node$expanded, info = name)
    expect_false(isTRUE(node$empty), info = name)
    expect_length(node$children, 0)
  }
})

# --- flat listing (file chooser, save dialog, folder chooser content pane) --

listing <- function(dir = "", ...) {
  fileGetter(roots = roots, ...)(dir = dir, root = "fx")
}

test_that("the flat listing marks folders exactly as an independent check does", {
  files <- listing()$files
  expected <- dir.exists(fs::path(fixture, files$filename))
  expect_equal(files$isdir, expected)
})

test_that("the flat listing treats a symlink to a folder as a folder", {
  files <- listing()$files
  isdir <- setNames(files$isdir, files$filename)
  expect_true(isdir[["linkToDir"]])
  expect_false(isdir[["linkToFile"]])
  expect_false(isdir[["brokenLink"]])
  expect_false(isdir[["looksLikeAFolder"]])
  expect_true(isdir[["full"]])
})

test_that("the flat listing keeps broken symlinks visible", {
  expect_true("brokenLink" %in% listing()$files$filename)
})

test_that("filetypes keep folders and drop other files in the flat listing", {
  files <- listing(filetypes = "txt")$files
  expect_true(all(files$isdir | files$extension == "txt"))
  expect_true("top.txt" %in% files$filename)
  expect_true("full" %in% files$filename)
  expect_true("linkToDir" %in% files$filename)
  expect_false("noext" %in% files$filename)
})

test_that("restrictions apply to the flat listing too", {
  files <- listing(restrictions = fs::path(fixture, "secret"))$files
  expect_false("secret" %in% files$filename)
  expect_true("full" %in% files$filename)
})

test_that("listing an unreadable folder returns nothing rather than erroring", {
  skip_if_not(lockedIsLocked(), "running with permissions that ignore chmod")
  res <- expect_no_error(listing("locked"))
  expect_equal(nrow(res$files), 0)
})

test_that("a collapsed folder known to be empty is re-checked, so new subfolders appear", {
  # The client refuses to expand a folder marked empty, so if the mark were
  # carried over unchecked, a folder created inside it (e.g. with the dialog's
  # own new-folder button) could never be opened.
  p <- fs::path(fixture, "fillsUp")
  fs::dir_create(p)
  on.exit(fs::dir_delete(p))
  dg <- dirGetter(roots = roots)
  echoed <- list(name = "", expanded = TRUE, children = list(
    list(name = "fillsUp", expanded = FALSE, empty = TRUE, children = list())
  ))
  expect_true(findChild(dg(tree = echoed, root = "fx")$tree, "fillsUp")$empty)

  fs::dir_create(fs::path(p, "new"))
  expect_false(findChild(dg(tree = echoed, root = "fx")$tree, "fillsUp")$empty)
})
