# Keeps inputs-catalogue.csv honest. Every interactive element a dialog renders
# must match a catalogue row for that dialog, so a control can't be added
# without a test, and every row must still point at something that exists.

library(shinytest2)

guardBase <- catalogueTree()
withr::local_envvar(c(SF_CATALOGUE_BASE = guardBase), .local_envir = teardown_env())
guardApp <- writeTestApp(catalogueAppLines, "sf-catalogue-guard")

# Every element with a click/key/change handler, described by the selector
# the catalogue uses for it.
listControls <- sprintf("
  (function(){
    var m = %s, out = [];
    var add = function(sel){ if (m.find(sel).length) out.push(sel); };
    m.find('button[id], select, input, li.sortAttr, li.sortDir a').each(function(){
      var e = $(this);
      if (this.id) return out.push('#' + this.id);
      if (e.is('select.sF-breadcrumps')) return out.push('select.sF-breadcrumps');
      if (e.is('li.sortAttr')) return out.push('.sF-sort li.sortAttr:contains(' + e.text().trim() + ')');
      if (e.is('li.sortDir a')) return out.push('.sF-sort li.sortDir a');
      if (e.is('.sF-textChoice input')) return out.push('.sF-textChoice input');
      if (e.is('.sF-newDir input')) return out.push('.sF-newDir input');
      if (e.is('input.sF-filename')) return out.push('input.sF-filename');
      out.push('UNKNOWN:' + this.outerHTML.slice(0, 80));
    });
    m.find('button.close').length && out.push('.modal-header button.close');
    add('.sF-textChoice ul button'); add('.sF-newDir ul button');
    add('.input-group-btn.sF-filetype li a');
    // File rows are clickable in the file and save dialogs; the folder dialog's
    // content pane is display only, so only its tree counts.
    add('.sF-fileList .sF-file'); add('.sF-fileList .sF-directory');
    add('.sF-dirList .sF-expander>span'); add('.sF-dirList .sF-file-name');
    return out.filter(function(v, i, a){ return a.indexOf(v) === i; })
      .map(function(v){ return v.replace(/^\\.sF-fileList /, ''); });
  })()", topModal)

test_that("every rendered control is in the catalogue", {
  skipUnlessBrowser()
  cat <- readCatalogue()
  app <- newApp(guardApp, "catalogue-guard")
  on.exit(app$stop(), add = TRUE)

  for (dialog in c("file", "dir", "save")) {
    openDialog(app, dialog)
    if (dialog == "dir") {
      # The content pane and new-folder button only fill in once a folder is selected.
      app$run_js(sprintf("%s.find('.sF-dirList .sF-file-name').first().trigger('click')", topModal))
      app$wait_for_idle()
    }
    found <- unlist(app$get_js(listControls))
    known <- cat$selector[cat$dialog == dialog]
    expect_equal(setdiff(found, known), character(0), label = paste(dialog, "uncatalogued controls"))
    closeDialogs(app)
  }
  expectNoAppErrors(app)
})

test_that("the catalogue is well formed", {
  cat <- readCatalogue()
  expect_named(cat, c("id", "dialog", "control", "selector", "action", "check", "notes"))
  expect_false(anyDuplicated(cat$id) > 0)
  expect_true(all(cat$dialog %in% c("file", "dir", "save")))
  expect_true(all(nzchar(cat$selector)))
  expect_true(all(grepl("^(click|dblclick|state|key:|select:|type:|click\\+)", cat$action)))
  # Every dialog has the same core controls.
  for (d in c("file", "dir", "save")) {
    rows <- cat[cat$dialog == d, ]
    for (core in c("#sF-cancelButton", "#sF-selectButton", "#sF-btn-refresh",
                   "#sF-btn-textChoice", "select.sF-breadcrumps", "#sF-btn-sort")) {
      expect_true(core %in% rows$selector, label = paste(d, core))
    }
  }
})
