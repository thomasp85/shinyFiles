"""Replay every row of tests/testthat/inputs-catalogue.csv with real mouse and
keyboard input, in each browser.

The shinytest2 suite (test-catalogue-e2e.R) checks the same rows from R. This
one exists for the browser side: real events, three engines, and JS coverage.
Each `check` column value names a function in CHECKS below.
"""

from __future__ import annotations

import os
import re
from pathlib import Path

import pytest
from playwright.sync_api import Page, expect

from helpers import KNOWN_BUGS, Dialog, catalogue_rows, shiny_input

ROWS = catalogue_rows()

# Which button each row opens. A few rows need a variant of the dialog.
VARIANT = {
    "folderNotCreated": "dirNoCreate",
    "viewFromArgument": "fileIcon",
    "singleFiletypeShown": "saveOne",
}
NOT_OPENED = {"file-open", "dir-open", "save-open"}


# Checks that pin a known bug. The row is marked xfail(strict=True), so it must
# fail now and must pass (forcing the entry's removal) once the bug is fixed.
KNOWN_BUG_CHECKS = {
}


# --- checks -------------------------------------------------------------------

def dialogOpen(page: Page, d: Dialog, row, fx):
    page.click(f"#{d.button_id}")
    expect(page.locator(".sF-modalContainer.in")).to_have_count(1)
    # Shiny's action-button binding sends the click count asynchronously.
    page.wait_for_function(f"() => Shiny.shinyapp.$inputValues[{(d.button_id + ':shiny.action')!r}] === 1")


def closedNoValue(page: Page, d: Dialog, row, fx):
    before = shiny_input(page, d.button_id)
    if row["action"].startswith("key:"):
        page.keyboard.press(row["action"][4:])
    elif row["selector"] == ".sF-modalContainer":
        # Outside the dialog box, inside the container.
        page.mouse.click(5, 5)
    else:
        d.find(row["selector"]).first.click()
    d.expect_closed()
    assert shiny_input(page, d.button_id) == before


def selectDisabled(page, d, row, fx):
    if d.button_id == "save":
        d.find("input.sF-filename").fill("")
    expect(d.find("#sF-selectButton")).to_be_disabled()


def valueIsSelection(page, d, row, fx):
    if row["action"] == "dblclick":
        d.dblclick_row("a.txt")
    else:
        d.click_row("a.txt")
        if row["action"].startswith("key:"):
            page.keyboard.press("Enter")
        else:
            d.find("#sF-selectButton").click()
    d.expect_closed()
    assert d.output("fileOut") == str(fx / "data" / "a.txt")


def valueIsFolder(page, d, row, fx):
    d.highlight("folder")
    if row["action"].startswith("key:"):
        page.keyboard.press("Enter")
    else:
        d.find("#sF-selectButton").click()
    d.expect_closed()
    assert d.output("dirOut") == str(fx / "data" / "folder")


def valueIsSave(page, d, row, fx):
    box = d.find("input.sF-filename")
    box.fill("newname")
    if row["action"].startswith("key:"):
        box.press("Enter")
    else:
        d.find("#sF-selectButton").click()
    d.expect_closed()
    assert d.output("saveOut") == f"{fx / 'data' / 'newname.txt'} text"


def navDisabledAtRoot(page, d, row, fx):
    for b in ("#sF-btn-back", "#sF-btn-up", "#sF-btn-forward"):
        expect(d.find(b)).to_be_disabled()


def openedFolder(page, d, row, fx):
    d.after_listing(lambda: d.dblclick_row("folder"))
    assert d.location() == ["", "folder"]


def wentUp(page, d, row, fx):
    openedFolder(page, d, row, fx)
    if row["action"].startswith("select:"):
        d.after_listing(lambda: d.select_option("$(this).val() === '' && !$(this).parent().is('optgroup')"))
    else:
        d.after_listing(lambda: d.find("#sF-btn-up").click())
    assert d.location() == [""]


def wentBack(page, d, row, fx):
    wentUp(page, d, {"action": "click"}, fx)
    d.after_listing(lambda: d.find("#sF-btn-back").click())
    assert d.location() == ["", "folder"]


def wentForward(page, d, row, fx):
    wentBack(page, d, row, fx)
    expect(d.find("#sF-btn-forward")).to_be_enabled()
    d.after_listing(lambda: d.find("#sF-btn-forward").click())
    assert d.location() == [""]


def viewIs(page, d, row, fx, cls):
    d.find(row["selector"]).click()
    expect(d.find(".sF-fileList")).to_have_class(re.compile(cls))
    expect(d.find(row["selector"])).to_have_class(re.compile("active"))


def viewFromArgument(page, d, row, fx):
    expect(d.find(".sF-fileList")).to_have_class(re.compile("sF-icons"))


def menuOpen(page, d, row, fx, menu):
    if menu == ".sF-newDir" and d.button_id.startswith("dir"):
        d.highlight_root()
    d.find(row["selector"]).click()
    expect(d.find(menu)).to_have_class(re.compile("open"))


SORTED = {"Name": ["a.txt", "b.csv", "c.R"], "Type": ["b.csv", "c.R", "a.txt"],
          "Size": ["b.csv", "c.R", "a.txt"]}


def sortedBy(page, d, row, fx, attr):
    if d.button_id.startswith("dir"):
        d.highlight_root()
    d.find("#sF-btn-sort").click()
    d.find(".sF-sort li.sortAttr").filter(has_text=attr).click()
    expect(d.find(".sF-sort li.sortAttr.selected")).to_have_text(attr)
    if not d.button_id.startswith("dir") and attr in SORTED:
        assert d.row_names(".sF-fileList > .sF-file") == SORTED[attr]
    assert page.evaluate(f"() => $('#{d.button_id}').data('sort')") == attr


def sortDirection(page, d, row, fx):
    if d.button_id.startswith("dir"):
        d.highlight_root()
    d.find("#sF-btn-sort").click()
    d.find(".sF-sort li.sortDir a").click()
    expect(d.find(".sF-sort li.sortDir a")).to_have_class(re.compile("descending"))
    if not d.button_id.startswith("dir"):
        assert d.row_names(".sF-fileList > .sF-file") == ["c.R", "b.csv", "a.txt"]


def pathBoxPrefilled(page, d, row, fx):
    d.find("#sF-btn-textChoice").click()
    expect(d.find(".sF-textChoice")).to_have_class(re.compile("open"))
    expect(d.find(".sF-textChoice input")).to_have_value("data")
    expect(d.find(".sF-textChoice input")).to_be_focused()


def typedPathNavigates(page, d, row, fx):
    d.find("#sF-btn-textChoice").click()
    box = d.find(".sF-textChoice input")
    box.fill(str(fx / "data" / "folder"))
    # The OK button enables on keyup, as when the user types.
    box.press("End")
    if row["action"].startswith("key:"):
        d.after_listing(lambda: box.press("Enter"))
    else:
        d.after_listing(lambda: d.find(".sF-textChoice ul button").click())
    if d.button_id.startswith("dir"):
        assert d.content_path() == ["", "folder"]
    else:
        assert d.location() == ["", "folder"]
    assert d.is_open()


def pathBoxClosedDialogOpen(page, d, row, fx):
    d.find("#sF-btn-textChoice").click()
    expect(d.find(".sF-textChoice input")).to_be_focused()
    page.keyboard.press("Escape")
    expect(d.find(".sF-textChoice")).not_to_have_class(re.compile("open"))
    assert d.is_open(), "dialog still open after Esc in the path box"


def newDirClosedDialogOpen(page, d, row, fx):
    if d.button_id.startswith("dir"):
        d.highlight_root()
    d.find("#sF-btn-newDir").click()
    expect(d.find(".sF-newDir input")).to_be_focused()
    page.keyboard.press("Escape")
    expect(d.find(".sF-newDir")).not_to_have_class(re.compile("open"))
    assert d.is_open()


def refreshSent(page, d, row, fx):
    if d.button_id.startswith("dir"):
        d.highlight_root()
    name = f"fresh-{row['id']}-{os.getpid()}.txt"
    new = fx / "data" / name
    new.touch()
    try:
        before = shiny_input(page, f"{d.button_id}-refresh")
        d.after_listing(lambda: d.find("#sF-btn-refresh").click())
        assert shiny_input(page, f"{d.button_id}-refresh") != before
        if d.button_id.startswith("dir"):
            expect(d.find(".sF-dirContent .sF-file-name", ).filter(has_text=name)).to_have_count(1)
        else:
            assert name in d.row_names()
    finally:
        new.unlink()


def volumeChanged(page, d, row, fx):
    d.after_listing(lambda: d.select_option(
        "$(this).parent().is('optgroup') && !$(this).parent().hasClass('sF-recent') && $(this).text().indexOf('other') !== -1"
    ))
    if d.button_id.startswith("dir"):
        assert d.js("return m.data('currentData').selectedRoot;") == "other"
    else:
        assert d.js("return m.find('.sF-breadcrumps').data('selectedRoot');") == "other"
        assert "elsewhere" in d.row_names()


def recentNavigates(page, d, row, fx):
    page.locator(".sF-modalContainer.in #sF-cancelButton").click()
    d.expect_closed()
    page.evaluate("""() => localStorage.setItem('shinyFiles-recent:' + location.pathname,
        JSON.stringify([{root: 'data', path: ['folder', 'sub']}]))""")
    d.open()
    expect(d.find("select.sF-breadcrumps optgroup.sF-recent option")).to_have_text(["data/folder/sub"])
    d.after_listing(lambda: d.select_option("$(this).parent().hasClass('sF-recent')"))
    if d.button_id.startswith("dir"):
        assert d.content_path() == ["", "folder", "sub"]
    else:
        assert d.location() == ["", "folder", "sub"]


def _new_folder(page, d, row, fx, enters: bool):
    name = f"new-{row['id']}-{page.context.browser.browser_type.name}"
    target = fx / "data" / name
    if d.button_id.startswith("dir"):
        d.highlight_root()
    d.find("#sF-btn-newDir").click()
    box = d.find(".sF-newDir input")
    box.fill(name)
    box.press("End")
    act = (lambda: box.press("Enter")) if row["action"].startswith("key:") \
        else (lambda: d.find(".sF-newDir ul button").click())
    try:
        if enters:
            d.after_listing(act)
            assert d.location() == ["", name]
        else:
            act()
            page.wait_for_timeout(500)
        assert target.is_dir()
    finally:
        if target.exists():
            target.rmdir()


def folderCreated(page, d, row, fx):
    _new_folder(page, d, row, fx, enters=False)


def folderCreatedAndEntered(page, d, row, fx):
    _new_folder(page, d, row, fx, enters=True)


def folderNotCreated(page, d, row, fx):
    d.highlight_root()
    d.find("#sF-btn-newDir").click()
    box = d.find(".sF-newDir input")
    box.fill("refused")
    box.press("End")
    box.press("Enter")
    expect(page.locator(".shiny-notification-error")).to_contain_text("disabled")
    assert not (fx / "data" / "refused").exists()


def _expander(d, name):
    return d.tree_node(name).locator(":scope > .sF-expander > span")


def treeExpanded(page, d, row, fx):
    d.after_listing(lambda: _expander(d, "folder").click())
    expect(d.tree_node("folder")).to_have_class(re.compile("expanded"))
    expect(d.tree_node("sub")).to_have_count(1)


def treeCollapsed(page, d, row, fx):
    treeExpanded(page, d, row, fx)
    d.after_listing(lambda: _expander(d, "folder").click())
    expect(d.tree_node("folder")).not_to_have_class(re.compile("expanded"))


def folderHighlighted(page, d, row, fx):
    d.highlight("folder")
    assert d.content_path() == ["", "folder"]
    expect(d.find(".sF-dirContent .sF-file-name").filter(has_text="f01.txt")).to_have_count(1)
    expect(d.find("#sF-selectButton")).to_be_enabled()


def folderUnhighlighted(page, d, row, fx):
    folderHighlighted(page, d, row, fx)
    d.highlight("folder")
    expect(d.find("#sF-selectButton")).to_be_disabled()


def treeSelectionMoved(page, d, row, fx):
    d.highlight_root()
    page.keyboard.press("ArrowDown")
    sel = d.js("return m.find('.sF-dirList .selected > .sF-file-name').text().trim();")
    assert sel and sel != "data"


def rowSelected(page, d, row, fx):
    d.click_row("b.csv")
    assert d.selected_rows() == ["b.csv"]
    expect(d.find("#sF-selectButton")).to_be_enabled()


def rowsToggled(page, d, row, fx):
    mod = "Meta" if page.context.browser.browser_type.name == "webkit" else "Control"
    d.click_row("a.txt")
    d.click_row("c.R", [mod])
    assert sorted(d.selected_rows()) == ["a.txt", "c.R"]
    d.click_row("a.txt", [mod])
    assert d.selected_rows() == ["c.R"]


def rangeSelected(page, d, row, fx):
    d.click_row("a.txt")
    d.click_row("c.R", ["Shift"])
    assert d.selected_rows() == ["a.txt", "b.csv", "c.R"]


def selectionCleared(page, d, row, fx):
    d.click_row("a.txt")
    box = d.find(".sF-fileWindow").bounding_box()
    page.mouse.click(box["x"] + box["width"] - 5, box["y"] + box["height"] - 5)
    assert d.selected_rows() == []
    expect(d.find("#sF-selectButton")).to_be_disabled()


def selectionMoved(page, d, row, fx):
    d.click_row("a.txt")
    page.keyboard.press("ArrowDown")
    assert d.selected_rows() == ["b.csv"]
    page.keyboard.press("ArrowUp")
    assert d.selected_rows() == ["a.txt"]


def overwriteWarned(page, d, row, fx):
    box = d.find("input.sF-filename")
    box.fill("a")
    expect(d.find("#sF-selectButton")).to_have_text("Overwrite")
    expect(d.find("#filenameWarn")).to_have_count(1)
    box.fill("unique")
    expect(d.find("#sF-selectButton")).to_have_text("Save")


def saveEnabled(page, d, row, fx):
    box = d.find("input.sF-filename")
    box.fill("")
    expect(d.find("#sF-selectButton")).to_be_disabled()
    box.fill("x")
    expect(d.find("#sF-selectButton")).to_be_enabled()


def filenameFromArgument(page, d, row, fx):
    expect(d.find("input.sF-filename")).to_have_value("report")


def filenameFromRow(page, d, row, fx):
    d.click_row("a.txt")
    expect(d.find("input.sF-filename")).to_have_value("a")


def singleFiletypeShown(page, d, row, fx):
    expect(d.find("span.input-group-addon.sF-filetype")).to_have_text(".R")
    expect(d.find(".input-group-btn.sF-filetype")).to_have_count(0)


def filetypeChosen(page, d, row, fx):
    d.find(".input-group-btn.sF-filetype > button").click()
    d.find(".input-group-btn.sF-filetype li a").filter(has_text="csv").click()
    expect(d.find(".input-group-btn.sF-filetype > button")).to_contain_text(".csv")
    d.find("input.sF-filename").fill("table")
    d.find("#sF-selectButton").click()
    d.expect_closed()
    assert d.output("saveOut") == f"{fx / 'data' / 'table.csv'} csv"


def permissionWarned(page, d, row, fx):
    d.after_listing(lambda: d.dblclick_row("locked"))
    expect(d.find(".sF-warning")).to_contain_text("No write permission", timeout=3000)
    d.find("input.sF-filename").fill("x")
    expect(d.find("#sF-selectButton")).to_be_disabled()


def missingWarned(page, d, row, fx):
    d.find("#sF-btn-textChoice").click()
    box = d.find(".sF-textChoice input")
    box.fill("/no/such/place/at/all")
    d.after_listing(lambda: box.press("Enter"))
    expect(d.find(".sF-warning")).to_contain_text("does not exist")


def overlayDuringSlowListing(page, d, row, fx):
    pytest.skip("covered in tests/testthat/test-typed-path-e2e.R with a deliberately slow app")


CHECKS = {name: fn for name, fn in globals().items() if callable(fn) and name[0].islower()
          and name not in {"catalogue_rows", "shiny_input", "expect"}}


def test_every_check_is_implemented():
    names = {r["check"].split(":")[0] for r in ROWS}
    assert names - set(CHECKS) == set()


def _param(row):
    bug = KNOWN_BUG_CHECKS.get(row["check"].split(":")[0])
    marks = [pytest.mark.xfail(reason=f"known bug: {KNOWN_BUGS[bug]}", strict=True)] if bug else []
    return pytest.param(row, id=row["id"], marks=marks)


@pytest.mark.parametrize("row", [_param(r) for r in ROWS])
def test_catalogue_row(app: Page, row, fixture_dir: Path):
    name, _, arg = row["check"].partition(":")
    button = VARIANT.get(name) or {"file": "file", "dir": "dir", "save": "save"}[row["dialog"]]
    d = Dialog(app, button)
    if row["id"] not in NOT_OPENED:
        d.open()
    fn = CHECKS[name]
    if arg:
        fn(app, d, row, fixture_dir, arg)
    else:
        fn(app, d, row, fixture_dir)
