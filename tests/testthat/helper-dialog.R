# Shared harness for driving the dialogs' server side with testServer(). The
# test plays the browser: each request it sends is the last response
# round-tripped through Shiny's own JSON encoding, with only the fields a click
# would change. testthat sources helper files before every test file.

library(shiny)

roundTrip <- function(x) {
  jsonlite::fromJSON(as.character(shiny:::toJSON(x)), simplifyVector = FALSE)
}

# Runs pending later::later() callbacks, as the event loop would between requests.
drainLater <- function() {
  for (i in seq_len(1000)) {
    if (later::loop_empty()) break
    later::run_now(0.05)
  }
}

# Drives shinyFileChoose() or shinyFileSave(), whose dialogs talk in
# {path, root, typed} requests. Inside `body`:
#   last()          the latest listing the browser was sent
#   messages()      every message type sent, in order
#   open()          the button click that opens the dialog
#   go(path, root)  navigate to a folder (path is a character vector)
#   type(text)      submit text from the path box
#   refresh()       the refresh button
#   newDir(name, path)  the new-folder button (save dialog only)
#   notifications() notifications shown with showNotification()
#   elapse(ms)      advance the session clock (for updateFreq)
withFileDialog <- function(observer, roots, body, id = "f", ...) {
  args <- list(...)
  server <- function(input, output, session) {
    do.call(observer, c(list(input, id, roots = roots, session = session), args))
  }
  testServer(server, {
    state <- new.env()
    state$last <- NULL
    state$types <- character(0)
    state$opens <- 0
    state$notes <- list()
    session$sendCustomMessage <- function(type, message) {
      if (!identical(message$id, session$ns(id))) return()
      state$types <- c(state$types, type)
      state$last <- roundTrip(message$dir)
    }
    local_mocked_bindings(
      showNotification = function(ui, ..., type = "default") {
        state$notes[[length(state$notes) + 1]] <- list(text = as.character(ui), type = type)
        invisible(NULL)
      },
      .package = "shiny"
    )
    setInput <- function(name, value) do.call(session$setInputs, setNames(list(value), name))
    modal <- function(value) setInput(paste0(id, "-modal"), value)
    api <- list(
      last = function() state$last,
      messages = function() state$types,
      open = function() {
        state$opens <- state$opens + 1
        setInput(id, state$opens)
      },
      go = function(path = character(0), root = state$last$root) {
        modal(list(path = c(list(""), as.list(path)), root = root))
      },
      type = function(text, root = state$last$root) {
        modal(list(path = list(""), root = root, typed = text, id = runif(1)))
      },
      refresh = function() setInput(paste0(id, "-refresh"), as.numeric(Sys.time()) + runif(1)),
      newDir = function(name, path = character(0), root = state$last$root) {
        setInput(paste0(id, "-newDir"), list(
          name = name, path = c(list(""), as.list(path)), root = root, id = runif(1)
        ))
      },
      notifications = function() state$notes,
      elapse = function(ms) session$elapse(ms),
      session = session
    )
    body(api)
  })
}

filenames <- function(listing) sort(unlist(listing$files$filename))
crumbs <- function(listing) unlist(listing$breadcrumps)
