"""Dialog behaviour that needs more than one catalogue action: sizes and
history, the loading overlay, recent folders across reloads, and what the
browser shows for each file."""

from __future__ import annotations

import re
from pathlib import Path

from playwright.sync_api import Page, expect

from helpers import Dialog


def test_file_sizes_are_shown_in_si_units(app: Page, fixture_dir: Path):
    big = fixture_dir / "data" / "big.bin"
    big.write_bytes(b"x" * 1_500_000)
    try:
        d = Dialog(app, "file").open()
        d.after_listing(lambda: d.find("#sF-btn-refresh").click())
        size = d.find(".sF-fileList .sF-file").filter(has_text="big.bin").locator(".sF-file-size")
        expect(size).to_have_text("1.5 MB")
        expect(d.find(".sF-fileList .sF-file").filter(has_text="b.csv").locator(".sF-file-size")).to_have_text(
            re.compile(r"^\d+ B$")
        )
    finally:
        big.unlink()


def test_folders_have_no_size(app: Page):
    d = Dialog(app, "file").open()
    expect(d.find(".sF-fileList .sF-directory").filter(has_text="folder").locator(".sF-file-size")).to_have_text("")


def test_history_survives_closing_and_reopening(app: Page):
    d = Dialog(app, "file").open()
    d.after_listing(lambda: d.dblclick_row("folder"))
    d.after_listing(lambda: d.find("#sF-btn-up").click())
    d.find("#sF-cancelButton").click()
    d.expect_closed()
    d.open()
    expect(d.find("#sF-btn-back")).to_be_enabled()
    d.after_listing(lambda: d.find("#sF-btn-back").click())
    assert d.location() == ["", "folder"]


def test_view_and_sort_survive_closing_and_reopening(app: Page):
    d = Dialog(app, "file").open()
    d.find("#sF-btn-list").click()
    d.find("#sF-btn-sort").click()
    d.find(".sF-sort li.sortAttr").filter(has_text="Size").click()
    d.find("#sF-cancelButton").click()
    d.expect_closed()
    d.open()
    expect(d.find(".sF-fileList")).to_have_class(re.compile("sF-list"))
    expect(d.find(".sF-sort li.sortAttr.selected")).to_have_text("Size")


def test_a_navigation_clears_forward_history(app: Page):
    d = Dialog(app, "file").open()
    d.after_listing(lambda: d.dblclick_row("folder"))
    d.after_listing(lambda: d.find("#sF-btn-back").click())
    expect(d.find("#sF-btn-forward")).to_be_enabled()
    d.after_listing(lambda: d.dblclick_row("empty"))
    expect(d.find("#sF-btn-forward")).to_be_disabled()


def test_selection_is_remembered_as_a_recent_folder(app: Page):
    d = Dialog(app, "file").open()
    d.after_listing(lambda: d.dblclick_row("folder"))
    d.click_row("f01.txt")
    d.find("#sF-selectButton").click()
    d.expect_closed()
    stored = app.evaluate("() => JSON.parse(localStorage.getItem('shinyFiles-recent:' + location.pathname))")
    assert stored == [{"root": "data", "path": ["folder"]}]
    # Survives a reload, and shows in a different dialog with the same roots.
    app.reload()
    app.wait_for_selector("button#save.shiny-bound-input")
    s = Dialog(app, "save").open()
    expect(s.find("select.sF-breadcrumps optgroup.sF-recent option")).to_have_text(["data/folder"])


def test_corrupt_recent_storage_is_ignored(app: Page):
    app.evaluate("() => localStorage.setItem('shinyFiles-recent:' + location.pathname, '{not json')")
    d = Dialog(app, "file").open()
    expect(d.find("select.sF-breadcrumps optgroup.sF-recent")).to_have_count(0)
    d.click_row("a.txt")
    d.find("#sF-selectButton").click()
    d.expect_closed()
    stored = app.evaluate("() => JSON.parse(localStorage.getItem('shinyFiles-recent:' + location.pathname))")
    assert stored == [{"root": "data", "path": []}]


def test_a_fast_listing_never_flashes_the_overlay(app: Page):
    Dialog(app, "file").open()
    result = app.evaluate("""() => new Promise(function(resolve) {
      var m = $('#file').data('modal');
      var shown = false;
      var timer = setInterval(function(){
        if (m.find('.sF-loading').length) shown = true;
      }, 20);
      // Navigating starts the overlay timer; a local listing lands well
      // under its 250 ms delay, so the overlay must never appear.
      m.find('.sF-fileList .sF-directory').filter(function(){
        return $(this).text().indexOf('folder') !== -1; }).trigger('dblclick');
      setTimeout(function(){ clearInterval(timer); resolve({shown: shown,
        gone: m.find('.sF-loading').length === 0}); }, 1000);
    })""")
    assert result["gone"]
    assert not result["shown"]


def test_every_file_row_carries_its_metadata(app: Page):
    d = Dialog(app, "file").open()
    info = d.js("""return m.find('.sF-fileList > .sF-file').map(function(){
        var f = $(this).data('sF-file');
        return {name: f.name, ext: f.extension, isDir: f.isDir, hasTimes: !!(f.mTime && f.cTime)};
      }).toArray();""")
    by_name = {x["name"]: x for x in info}
    assert by_name["a.txt"]["ext"] == "txt"
    assert by_name["c.R"]["ext"] == "r"
    assert all(x["hasTimes"] and not x["isDir"] for x in info)


def test_only_the_save_dialog_warns_about_a_read_only_folder(app: Page):
    d = Dialog(app, "file").open()
    d.after_listing(lambda: d.dblclick_row("locked"))
    expect(d.find(".sF-warning")).to_have_count(0)
    d.find("#sF-cancelButton").click()
    d.expect_closed()
    t = Dialog(app, "dir").open()
    t.highlight("locked")
    expect(t.find(".sF-warning")).to_have_count(0)
    expect(t.find("#sF-btn-newDir")).to_be_disabled()
    expect(t.find("#sF-selectButton")).to_be_enabled()


def test_a_missing_folder_wins_over_the_permission_warning(app: Page):
    d = Dialog(app, "save").open()
    d.find("#sF-btn-textChoice").click()
    box = d.find(".sF-textChoice input")
    box.fill("/no/such/place")
    d.after_listing(lambda: box.press("Enter"))
    expect(d.find(".sF-warning")).to_have_count(1)
    expect(d.find(".sF-warning")).to_contain_text("does not exist")
