# Drives every row of inputs-catalogue.csv in a real browser and checks what
# it should do, on the page and in the value Shiny receives. Each row's
# `check` names one of the functions in `checks` below.
#
# Clicks go through jQuery's trigger() so they hit the dialog's own handlers.
# Keys are dispatched as keydown/keyup events with keyCode set, which is what
# the handlers read. Playwright (tests/playwright/) repeats the catalogue with
# real mouse and keyboard input in three browsers.

library(shinytest2)

catBase <- catalogueTree()
withr::local_envvar(c(SF_CATALOGUE_BASE = catBase), .local_envir = teardown_env())
catApp <- writeTestApp(catalogueAppLines, "sf-catalogue")
catalogue <- readCatalogue()

# Rows whose correct behaviour is pinned here but which fail on main because of
# a bug. Each is skipped with its reason until the fix lands, and the fix
# commit deletes its entry, so the test then has to pass.
KNOWN_BUGS <- c()
knownBug <- function(id) skip(paste("known bug:", KNOWN_BUGS[[id]]))

# --- page helpers -----------------------------------------------------------

js <- function(app, code) app$get_js(sprintf("(function(){ var m = %s; %s })()", topModal, code))
run <- function(app, code) {
  app$run_js(sprintf("(function(){ var m = %s; %s })()", topModal, code))
  app$wait_for_idle()
}

keyEvent <- function(target, type, key) {
  code <- c(Enter = 13, Escape = 27, ArrowLeft = 37, ArrowUp = 38, ArrowRight = 39, ArrowDown = 40)[[key]]
  sprintf("var e = $.Event('%s'); e.keyCode = %d; e.which = %d; %s.trigger(e);",
          type, code, code, target)
}

# A real key press through Chrome's input pipeline, delivered to whatever has
# focus. Needed where the handler reads the browser's own `event` object
# (handleArrowKey), which a jQuery-triggered event never sets, and where the
# point is how keydown and keyup handlers interact.
pressKey <- function(app, key) {
  code <- c(Enter = 13, Escape = 27, ArrowLeft = 37, ArrowUp = 38, ArrowRight = 39, ArrowDown = 40)[[key]]
  cdp <- app$get_chromote_session()
  for (type in c("keyDown", "keyUp")) {
    cdp$Input$dispatchKeyEvent(type = type, key = key, code = key, windowsVirtualKeyCode = code)
  }
  app$wait_for_idle()
}

# Waits for the next listing the server sends to this dialog.
waitListing <- function(app) {
  app$wait_for_js(sprintf("(%s.data('currentData') || {}).__seen !== true", topModal), timeout = 15000)
  app$wait_for_idle()
}
markListing <- function(app) run(app, "if (m.data('currentData')) m.data('currentData').__seen = true;")

location <- function(app) {
  unlist(js(app, "return m.find('.sF-breadcrumps>option').map(function(){ return $(this).val(); }).toArray().reverse();"))
}
dialogOpen <- function(app) isTRUE(app$get_js("$('.sF-modalContainer:visible').length > 0"))
rowNames <- function(app, sel = ".sF-fileList > .sF-file, .sF-fileList > .sF-directory") {
  unlist(js(app, sprintf(
    "return m.find('%s').map(function(){ return $(this).find('.sF-file-name').text().trim(); }).toArray();", sel)))
}
selectedRows <- function(app) {
  unlist(js(app, "return m.find('.sF-fileList .selected .sF-file-name').map(function(){ return $(this).text().trim(); }).toArray();"))
}
clickRow <- function(app, name, mods = "") {
  run(app, sprintf("
    var el = m.find('.sF-fileList').children().filter(function(){
      return $(this).find('.sF-file-name').text().trim() === %s; });
    var e = $.Event('click'); e.button = 0; %s
    el.trigger(e);", jsString(name), mods))
}
inputValue <- function(app, id) app$get_value(input = id)
output <- function(app, id) {
  v <- app$get_value(output = id)
  if (is.list(v)) "" else v
}
waitClosed <- function(app) {
  app$wait_for_js("$('.sF-modalContainer').length === 0", timeout = 10000)
  app$wait_for_idle()
}

# Leave the dialog in a state where `row` makes sense.
prepare <- function(app, row) {
  dialog <- switch(row$dialog, file = "file", dir = "dir", save = "save")
  if (row$check == "folderNotCreated") dialog <- "dirNoCreate"
  if (row$check == "viewFromArgument") dialog <- "fileIcon"
  if (row$check %in% c("singleFiletypeShown")) dialog <- "saveOne"
  if (row$id %in% c("file-open", "dir-open", "save-open")) return(dialog)
  openDialog(app, dialog)
  dialog
}

highlightFirstFolder <- function(app) {
  markListing(app)
  run(app, "m.find('.sF-dirList .sF-directory.root > .sF-file-name').first().trigger('click');")
  waitListing(app)
}

# --- checks: one per `check` value in the catalogue ---------------------------

checks <- list(
  dialogOpen = function(app, row, dialog) {
    app$click(dialog)
    waitForSelector(app, ".sF-modalContainer.in")
    expect_true(dialogOpen(app))
    expect_equal(inputValue(app, dialog), 1L)
  },

  closedNoValue = function(app, row, dialog) {
    before <- inputValue(app, dialog)
    sel <- row$selector
    if (row$action == "click" && sel == ".sF-modalContainer") {
      run(app, "m.trigger('click');")
    } else if (startsWith(row$action, "key:")) {
      run(app, keyEvent("$(document)", "keydown", sub("key:", "", row$action)))
    } else {
      run(app, sprintf("m.find(%s).first().trigger('click');", jsString(sel)))
    }
    waitClosed(app)
    expect_false(dialogOpen(app))
    expect_equal(inputValue(app, dialog), before)
  },

  selectDisabled = function(app, row, dialog) {
    if (dialog == "save") run(app, "m.find('.sF-filename').val('').trigger('input');")
    expect_true(js(app, "return m.find('#sF-selectButton').prop('disabled');"))
  },

  valueIsSelection = function(app, row, dialog) {
    if (row$action == "dblclick") {
      run(app, "var el = m.find('.sF-fileList .sF-file').filter(function(){ return $(this).text().indexOf('a.txt') !== -1; }); var e = $.Event('dblclick'); e.button = 0; el.trigger(e);")
    } else {
      clickRow(app, "a.txt")
      if (startsWith(row$action, "key:")) run(app, keyEvent("$(document)", "keydown", "Enter"))
      else run(app, "m.find('#sF-selectButton').trigger('click');")
    }
    waitClosed(app)
    app$wait_for_value(output = "fileOut", ignore = list(NULL, ""))
    expect_equal(output(app, "fileOut"), file.path(catBase, "data", "a.txt"))
  },

  valueIsFolder = function(app, row, dialog) {
    markListing(app)
    run(app, "m.find('.sF-dirList .sF-file-name').filter(function(){ return $(this).text().trim() === 'folder'; }).trigger('click');")
    waitListing(app)
    if (startsWith(row$action, "key:")) run(app, keyEvent("$(document)", "keydown", "Enter"))
    else run(app, "m.find('#sF-selectButton').trigger('click');")
    waitClosed(app)
    app$wait_for_value(output = "dirOut", ignore = list(NULL, ""))
    expect_equal(output(app, "dirOut"), file.path(catBase, "data", "folder"))
  },

  valueIsSave = function(app, row, dialog) {
    run(app, "m.find('.sF-filename').val('newname').trigger('input');")
    if (startsWith(row$action, "key:")) {
      run(app, "m.find('.sF-filename').focus();")
      run(app, keyEvent("$(document)", "keydown", "Enter"))
    } else {
      run(app, "m.find('#sF-selectButton').trigger('click');")
    }
    waitClosed(app)
    app$wait_for_value(output = "saveOut", ignore = list(NULL, ""))
    expect_equal(output(app, "saveOut"), paste(file.path(catBase, "data", "newname.txt"), "text"))
  },

  navDisabledAtRoot = function(app, row, dialog) {
    expect_true(js(app, "return m.find('#sF-btn-back').prop('disabled');"))
    expect_true(js(app, "return m.find('#sF-btn-up').prop('disabled');"))
    expect_true(js(app, "return m.find('#sF-btn-forward').prop('disabled');"))
  },

  openedFolder = function(app, row, dialog) {
    markListing(app)
    run(app, "var el = m.find('.sF-fileList .sF-directory').filter(function(){ return $(this).text().indexOf('folder') !== -1; }); var e = $.Event('dblclick'); e.button = 0; el.trigger(e);")
    waitListing(app)
    expect_equal(location(app), c("", "folder"))
  },

  wentUp = function(app, row, dialog) {
    markListing(app)
    run(app, "var el = m.find('.sF-fileList .sF-directory').filter(function(){ return $(this).text().indexOf('folder') !== -1; }); var e = $.Event('dblclick'); e.button = 0; el.trigger(e);")
    waitListing(app)
    expect_equal(location(app), c("", "folder"))
    markListing(app)
    if (startsWith(row$action, "select:")) {
      run(app, "var s = m.find('.sF-breadcrumps'); s.find('option').filter(function(){ return $(this).val() === ''; }).first().prop('selected', true); s.trigger('change');")
    } else {
      run(app, "m.find('#sF-btn-up').trigger('click');")
    }
    waitListing(app)
    expect_equal(location(app), "")
  },

  wentBack = function(app, row, dialog) {
    checks$wentUp(app, list(action = "click"), dialog)
    markListing(app)
    run(app, "m.find('#sF-btn-back').trigger('click');")
    waitListing(app)
    expect_equal(location(app), c("", "folder"))
  },

  wentForward = function(app, row, dialog) {
    checks$wentBack(app, row, dialog)
    expect_false(js(app, "return m.find('#sF-btn-forward').prop('disabled');"))
    markListing(app)
    run(app, "m.find('#sF-btn-forward').trigger('click');")
    waitListing(app)
    expect_equal(location(app), "")
  },

  viewIs = function(app, row, dialog, arg) {
    run(app, sprintf("m.find(%s).trigger('click');", jsString(row$selector)))
    expect_true(js(app, sprintf("return m.find('.sF-fileList').hasClass(%s);", jsString(arg))))
    expect_true(js(app, sprintf("return m.find(%s).hasClass('active');", jsString(row$selector))))
  },

  viewFromArgument = function(app, row, dialog) {
    expect_true(js(app, "return m.find('.sF-fileList').hasClass('sF-icons');"))
  },

  menuOpen = function(app, row, dialog, arg) {
    if (arg == ".sF-newDir" && dialog != "save") highlightFirstFolder(app)
    run(app, sprintf("m.find(%s).trigger('click');", jsString(row$selector)))
    expect_true(js(app, sprintf("return m.find(%s).hasClass('open');", jsString(arg))))
  },

  sortedBy = function(app, row, dialog, arg) {
    if (dialog == "dir") {
      markListing(app)
      run(app, "m.find('.sF-dirList .sF-directory.root > .sF-file-name').first().trigger('click');")
      waitListing(app)
    }
    run(app, sprintf("m.find('.sF-sort li.sortAttr').filter(function(){ return $(this).text().trim() === %s; }).trigger('click');", jsString(arg)))
    expect_true(js(app, sprintf("return m.find('.sF-sort li.sortAttr.selected').text().trim() === %s;", jsString(arg))))
    if (dialog != "dir") {
      files <- rowNames(app, ".sF-fileList > .sF-file")
      expected <- switch(arg,
        Name = c("a.txt", "b.csv", "c.R"),
        Type = c("b.csv", "c.R", "a.txt"),
        Size = c("b.csv", "c.R", "a.txt"),
        NULL
      )
      if (!is.null(expected)) expect_equal(files, expected, label = paste("files sorted by", arg))
    }
    expect_equal(app$get_js(sprintf("$('#%s').data('sort')", dialog)), arg)
  },

  sortDirection = function(app, row, dialog) {
    if (dialog == "dir") highlightFirstFolder(app)
    run(app, "m.find('.sF-sort li.sortDir').trigger('click');")
    expect_true(js(app, "return m.find('.sF-sort li.sortDir a').hasClass('descending');"))
    if (dialog != "dir") expect_equal(rowNames(app, ".sF-fileList > .sF-file"), c("c.R", "b.csv", "a.txt"))
    run(app, "m.find('.sF-sort li.sortDir').trigger('click');")
    expect_true(js(app, "return m.find('.sF-sort li.sortDir a').hasClass('ascending');"))
  },

  pathBoxPrefilled = function(app, row, dialog) {
    run(app, "m.find('.sF-textChoice').trigger('click');")
    expect_true(js(app, "return m.find('.sF-textChoice').hasClass('open');"))
    expect_equal(js(app, "return m.find('.sF-textChoice input').val();"), "data")
  },

  typedPathNavigates = function(app, row, dialog) {
    run(app, "m.find('.sF-textChoice').trigger('click');")
    target <- file.path(catBase, "data", "folder")
    run(app, sprintf("m.find('.sF-textChoice input').val(%s);", jsString(target)))
    markListing(app)
    if (startsWith(row$action, "key:")) {
      run(app, keyEvent("m.find('.sF-textChoice input')", "keyup", "Enter"))
    } else {
      run(app, keyEvent("m.find('.sF-textChoice input')", "keyup", "ArrowLeft"))
      run(app, "m.find('.sF-textChoice ul button').trigger('click');")
    }
    waitListing(app)
    if (dialog == "dir") {
      expect_equal(unlist(js(app, "return m.data('currentData').contentPath;")), c("", "folder"))
    } else {
      expect_equal(location(app), c("", "folder"))
    }
    expect_true(dialogOpen(app))
  },

  pathBoxClosedDialogOpen = function(app, row, dialog) {
    run(app, "m.find('.sF-textChoice').trigger('click');")
    expect_equal(app$get_js("document.activeElement.placeholder || ''"), "Enter Path")
    pressKey(app, "Escape")
    expect_false(js(app, "return m.find('.sF-textChoice').hasClass('open');"))
    expect_true(dialogOpen(app), label = "dialog still open after Esc in the path box")
  },

  newDirClosedDialogOpen = function(app, row, dialog) {
    if (dialog == "dir") highlightFirstFolder(app)
    run(app, "m.find('.sF-newDir').trigger('click');")
    expect_true(js(app, "return m.find('.sF-newDir').hasClass('open');"))
    run(app, keyEvent("m.find('.sF-newDir input')", "keydown", "Escape"))
    run(app, keyEvent("m.find('.sF-newDir input')", "keyup", "Escape"))
    expect_false(js(app, "return m.find('.sF-newDir').hasClass('open');"))
    expect_true(dialogOpen(app))
  },

  refreshSent = function(app, row, dialog) {
    if (dialog == "dir") highlightFirstFolder(app)
    name <- paste0("fresh-", row$id, ".txt")
    on.exit(unlink(file.path(catBase, "data", name)), add = TRUE)
    file.create(file.path(catBase, "data", name))
    before <- inputValue(app, paste0(dialog, "-refresh"))
    markListing(app)
    run(app, "m.find('#sF-btn-refresh').trigger('click');")
    waitListing(app)
    expect_false(identical(inputValue(app, paste0(dialog, "-refresh")), before))
    shown <- if (dialog == "dir") {
      unlist(js(app, "return m.find('.sF-dirContent .sF-file-name').map(function(){ return $(this).text().trim(); }).toArray();"))
    } else rowNames(app)
    expect_true(name %in% shown)
  },

  volumeChanged = function(app, row, dialog) {
    markListing(app)
    if (dialog == "dir") {
      run(app, "var s = m.find('.sF-breadcrumps'); s.val('other'); s.trigger('change');")
      waitListing(app)
      expect_equal(js(app, "return m.data('currentData').selectedRoot;"), "other")
    } else {
      run(app, "var s = m.find('.sF-breadcrumps'); s.find('optgroup[label=Volumes] option').filter(function(){ return $(this).val() === 'other'; }).prop('selected', true); s.trigger('change');")
      waitListing(app)
      expect_equal(js(app, "return m.find('.sF-breadcrumps').data('selectedRoot');"), "other")
      expect_true("elsewhere" %in% rowNames(app))
    }
  },

  recentNavigates = function(app, row, dialog) {
    closeDialogs(app)
    app$run_js("window.localStorage.setItem('shinyFiles-recent:' + window.location.pathname, JSON.stringify([{root: 'data', path: ['folder', 'sub']}]));")
    openDialog(app, dialog)
    labels <- unlist(js(app, "return m.find('.sF-breadcrumps optgroup.sF-recent option').map(function(){ return $(this).text(); }).toArray();"))
    expect_equal(labels, "data/folder/sub")
    markListing(app)
    run(app, "var s = m.find('.sF-breadcrumps'); s.find('optgroup.sF-recent option').first().prop('selected', true); s.trigger('change');")
    waitListing(app)
    if (dialog == "dir") {
      expect_equal(unlist(js(app, "return m.data('currentData').contentPath;")), c("", "folder", "sub"))
    } else {
      expect_equal(location(app), c("", "folder", "sub"))
    }
    app$run_js("window.localStorage.clear();")
  },

  folderCreated = function(app, row, dialog) {
    name <- paste0("new-", row$id)
    highlightFirstFolder(app)
    run(app, "m.find('.sF-newDir').trigger('click');")
    run(app, sprintf("m.find('.sF-newDir input').val(%s);", jsString(name)))
    markListing(app)
    if (startsWith(row$action, "key:")) {
      run(app, keyEvent("m.find('.sF-newDir input')", "keyup", "Enter"))
    } else {
      run(app, keyEvent("m.find('.sF-newDir input')", "keyup", "ArrowLeft"))
      run(app, "m.find('.sF-newDir ul button').trigger('click');")
    }
    app$wait_for_idle()
    expect_true(dir.exists(file.path(catBase, "data", name)))
    unlink(file.path(catBase, "data", name), recursive = TRUE)
  },

  folderCreatedAndEntered = function(app, row, dialog) {
    name <- paste0("new-", row$id)
    run(app, "m.find('.sF-newDir').trigger('click');")
    run(app, sprintf("m.find('.sF-newDir input').val(%s);", jsString(name)))
    markListing(app)
    if (startsWith(row$action, "key:")) {
      run(app, keyEvent("m.find('.sF-newDir input')", "keyup", "Enter"))
    } else {
      run(app, keyEvent("m.find('.sF-newDir input')", "keyup", "ArrowLeft"))
      run(app, "m.find('.sF-newDir ul button').trigger('click');")
    }
    waitListing(app)
    expect_true(dir.exists(file.path(catBase, "data", name)))
    expect_equal(location(app), c("", name))
    unlink(file.path(catBase, "data", name), recursive = TRUE)
  },

  folderNotCreated = function(app, row, dialog) {
    highlightFirstFolder(app)
    # Grayed out, so clicking it doesn't open the name box.
    expect_true(js(app, "return m.find('#sF-btn-newDir').prop('disabled');"))
    run(app, "m.find('.sF-newDir').trigger('click');")
    expect_false(js(app, "return m.find('.sF-newDir').hasClass('open');"))
    # And the server still refuses a request that gets through anyway.
    app$run_js(sprintf(
      "Shiny.setInputValue('%s-newDir', {name: 'refused', path: [''], root: 'data', id: Date.now()});",
      dialog
    ))
    app$wait_for_idle()
    expect_false(dir.exists(file.path(catBase, "data", "refused")))
    expect_true(app$get_js("$('.shiny-notification-error').text().indexOf('disabled') !== -1"))
  },

  treeExpanded = function(app, row, dialog) {
    markListing(app)
    run(app, "m.find('.sF-dirList .sF-directory').filter(function(){ return $(this).children('.sF-file-name').text().trim() === 'folder'; }).children('.sF-expander').children('span').trigger('click');")
    waitListing(app)
    expect_true(js(app, "return m.find('.sF-dirList .sF-directory').filter(function(){ return $(this).children('.sF-file-name').text().trim() === 'folder'; }).hasClass('expanded');"))
    expect_true("sub" %in% unlist(js(app, "return m.find('.sF-dirList .sF-file-name').map(function(){ return $(this).text().trim(); }).toArray();")))
  },

  treeCollapsed = function(app, row, dialog) {
    checks$treeExpanded(app, row, dialog)
    markListing(app)
    run(app, "m.find('.sF-dirList .sF-directory').filter(function(){ return $(this).children('.sF-file-name').text().trim() === 'folder'; }).children('.sF-expander').children('span').trigger('click');")
    waitListing(app)
    expect_false(js(app, "return m.find('.sF-dirList .sF-directory').filter(function(){ return $(this).children('.sF-file-name').text().trim() === 'folder'; }).hasClass('expanded');"))
  },

  folderHighlighted = function(app, row, dialog) {
    markListing(app)
    run(app, "m.find('.sF-dirList .sF-file-name').filter(function(){ return $(this).text().trim() === 'folder'; }).trigger('click');")
    waitListing(app)
    expect_equal(unlist(js(app, "return m.data('currentData').contentPath;")), c("", "folder"))
    shown <- unlist(js(app, "return m.find('.sF-dirContent .sF-file-name').map(function(){ return $(this).text().trim(); }).toArray();"))
    expect_true(all(c("sub", "f01.txt") %in% shown))
    expect_false(js(app, "return m.find('#sF-selectButton').prop('disabled');"))
  },

  folderUnhighlighted = function(app, row, dialog) {
    checks$folderHighlighted(app, row, dialog)
    markListing(app)
    run(app, "m.find('.sF-dirList .sF-file-name').filter(function(){ return $(this).text().trim() === 'folder'; }).trigger('click');")
    waitListing(app)
    expect_true(js(app, "return m.find('#sF-selectButton').prop('disabled');"))
  },

  treeSelectionMoved = function(app, row, dialog) {
    highlightFirstFolder(app)
    markListing(app)
    pressKey(app, "ArrowDown")
    selected <- js(app, "return m.find('.sF-dirList .selected > .sF-file-name').text().trim();")
    expect_true(nzchar(selected))
    expect_false(identical(selected, "data"))
  },

  rowSelected = function(app, row, dialog) {
    clickRow(app, "b.csv")
    expect_equal(selectedRows(app), "b.csv")
    expect_false(js(app, "return m.find('#sF-selectButton').prop('disabled');"))
  },

  rowsToggled = function(app, row, dialog) {
    clickRow(app, "a.txt")
    clickRow(app, "c.R", "e.ctrlKey = true;")
    expect_setequal(selectedRows(app), c("a.txt", "c.R"))
    clickRow(app, "a.txt", "e.ctrlKey = true;")
    expect_equal(selectedRows(app), "c.R")
  },

  rangeSelected = function(app, row, dialog) {
    clickRow(app, "a.txt")
    clickRow(app, "c.R", "e.shiftKey = true;")
    expect_equal(selectedRows(app), c("a.txt", "b.csv", "c.R"))
  },

  selectionCleared = function(app, row, dialog) {
    clickRow(app, "a.txt")
    run(app, "m.find('.sF-fileWindow').trigger('click');")
    expect_length(selectedRows(app), 0)
    expect_true(js(app, "return m.find('#sF-selectButton').prop('disabled');"))
  },

  selectionMoved = function(app, row, dialog) {
    clickRow(app, "a.txt")
    pressKey(app, "ArrowDown")
    expect_equal(selectedRows(app), "b.csv")
    pressKey(app, "ArrowUp")
    expect_equal(selectedRows(app), "a.txt")
  },

  overwriteWarned = function(app, row, dialog) {
    run(app, "m.find('.sF-filename').val('a').trigger('input');")
    expect_equal(js(app, "return m.find('#sF-selectButton').text();"), "Overwrite")
    expect_true(js(app, "return m.find('#sF-selectButton').hasClass('btn-warning');"))
    expect_true(js(app, "return m.find('#filenameWarn').length === 1;"))
    run(app, "m.find('.sF-filename').val('unique').trigger('input');")
    expect_equal(js(app, "return m.find('#sF-selectButton').text();"), "Save")
  },

  saveEnabled = function(app, row, dialog) {
    run(app, "m.find('.sF-filename').val('').trigger('input');")
    expect_true(js(app, "return m.find('#sF-selectButton').prop('disabled');"))
    run(app, "m.find('.sF-filename').val('x').trigger('input');")
    expect_false(js(app, "return m.find('#sF-selectButton').prop('disabled');"))
  },

  filenameFromArgument = function(app, row, dialog) {
    expect_equal(js(app, "return m.find('.sF-filename').val();"), "report")
  },

  filenameFromRow = function(app, row, dialog) {
    clickRow(app, "a.txt")
    # The .txt type is selected, so its extension is dropped from the box.
    expect_equal(js(app, "return m.find('.sF-filename').val();"), "a")
  },

  singleFiletypeShown = function(app, row, dialog) {
    expect_equal(js(app, "return m.find('span.input-group-addon.sF-filetype').text().trim();"), ".R")
    expect_equal(js(app, "return m.find('.input-group-btn.sF-filetype').length;"), 0L)
  },

  filetypeChosen = function(app, row, dialog) {
    run(app, "m.find('.input-group-btn.sF-filetype li a').filter(function(){ return $(this).text().indexOf('csv') === 0; }).trigger('click');")
    expect_match(js(app, "return m.find('.input-group-btn.sF-filetype > button').text();"), ".csv", fixed = TRUE)
    run(app, "m.find('.sF-filename').val('table').trigger('input');")
    run(app, "m.find('#sF-selectButton').trigger('click');")
    waitClosed(app)
    app$wait_for_value(output = "saveOut", ignore = list(NULL, ""))
    expect_equal(output(app, "saveOut"), paste(file.path(catBase, "data", "table.csv"), "csv"))
  },

  permissionWarned = function(app, row, dialog) {
    skip_if(Sys.info()[["effective_user"]] == "root", "root can write anywhere")
    markListing(app)
    run(app, "var el = m.find('.sF-fileList .sF-directory').filter(function(){ return $(this).text().indexOf('locked') !== -1; }); var e = $.Event('dblclick'); e.button = 0; el.trigger(e);")
    waitListing(app)
    expect_match(js(app, "return m.find('.sF-warning').text();"), "No write permission")
    run(app, "m.find('.sF-filename').val('x').trigger('input');")
    expect_true(js(app, "return m.find('#sF-selectButton').prop('disabled');"))
  },

  missingWarned = function(app, row, dialog) {
    run(app, "m.find('.sF-textChoice').trigger('click');")
    run(app, "m.find('.sF-textChoice input').val('/no/such/place/at/all');")
    markListing(app)
    run(app, keyEvent("m.find('.sF-textChoice input')", "keyup", "Enter"))
    waitListing(app)
    expect_match(js(app, "return m.find('.sF-warning').text();"), "does not exist")
  },

  overlayDuringSlowListing = function(app, row, dialog) {
    skip("covered in test-typed-path-e2e.R, which uses a deliberately slow app")
  }
)

# --- run every row ------------------------------------------------------------

test_that("every catalogue check has an implementation", {
  names <- sub(":.*", "", catalogue$check)
  expect_equal(setdiff(names, names(checks)), character(0))
})

# One app for the whole file; each row resets the page instead.
catApp_driver <- NULL
getApp <- function() {
  if (is.null(catApp_driver)) {
    catApp_driver <<- newApp(catApp, "catalogue")
    withr::defer(try(catApp_driver$stop(), silent = TRUE), envir = teardown_env())
  }
  catApp_driver
}

for (i in seq_len(nrow(catalogue))) {
  row <- catalogue[i, ]
  test_that(sprintf("[%s] %s: %s", row$id, row$control, row$check), {
    skipUnlessBrowser()
    app <- getApp()
    # Start every row from a clean page: no open dialogs, no stored recents, and
    # none of the state a button keeps between openings (last listing, history,
    # view, sort), so one row's navigation can't leak into the next.
    app$run_js("
      $('.sF-modalContainer, .sF-modalBackdrop').remove();
      $('.shinyFiles, .shinyDirectories, .shinySave').each(function(){
        var b = $(this);
        b.prop('disabled', false).removeData('modal dataCache back forward sort sortDir directory files file');
        b.data('view', b.attr('data-view') || '');
      });
      $('.shiny-notification').remove();
      window.localStorage.clear();
    ")
    # The server keeps its own idea of where each dialog is; send it home too.
    for (id in c("file", "fileIcon", "dir", "dirNoCreate", "save", "saveOne")) {
      app$run_js(sprintf("Shiny.setInputValue('%s-modal', null);", id))
    }
    app$wait_for_idle()
    dialog <- prepare(app, row)
    parts <- strsplit(row$check, ":", fixed = TRUE)[[1]]
    fn <- checks[[parts[1]]]
    if (length(parts) > 1) fn(app, row, dialog, parts[2]) else fn(app, row, dialog)
    expectNoAppErrors(app, row$id)
  })
}
