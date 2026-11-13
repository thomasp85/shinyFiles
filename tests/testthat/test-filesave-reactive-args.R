# Pins the bug reported in shinyFiles/shinyFiles#195: shinyFileChoose() defers
# building its fileGetter/dirCreator until sendDirectoryData() runs (inside an
# observer, so a reactive context is active), but shinyFileSave() built them
# once at setup time, outside any reactive consumer. A real app calls
# shinyFileSave() directly from its server function body -- not from inside
# testServer(), which wraps setup code in an implicit reactive domain and so
# would mask this -- which is why these tests call it directly with a mock
# session instead.
#
# Contract under test: passing a reactive expression as one of shinyFileSave's
# `...` arguments (e.g. `filetypes = reactive(...)`) must not error at setup
# time, matching shinyFileChoose's existing behavior.

callSetup <- function(roots, ...) {
  shinyFileSave(
    input = list(),
    id = "save",
    roots = roots,
    session = shiny::MockShinySession$new(),
    ...
  )
}

test_that("a reactive expression as a `...` arg does not error at setup time", {
  expect_no_error(
    callSetup(roots = c(wd = tempdir()), filetypes = shiny::reactive(c(txt = "txt")))
  )
})

test_that("a reactive roots argument does not error at setup time", {
  expect_no_error(
    callSetup(roots = shiny::reactive(c(wd = tempdir())))
  )
})

test_that("shinyFileChoose already tolerates a reactive `...` arg (reference behavior)", {
  expect_no_error(
    shinyFileChoose(
      input = list(),
      id = "files",
      roots = c(wd = tempdir()),
      session = shiny::MockShinySession$new(),
      filetypes = shiny::reactive(c(txt = "txt"))
    )
  )
})
