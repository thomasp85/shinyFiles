"""Keyboard navigation, beyond the single arrow press in the catalogue.

Arrow keys move the selection differently in each view (icon grid, list
columns, detail rows), extend it with Shift, and walk the folder tree. The
folder fixture has twelve files (f01..f12) so ranges cross into two-digit
indices.
"""

from __future__ import annotations

import re

import pytest
from playwright.sync_api import Page, expect

from helpers import KNOWN_BUGS, Dialog

FILES = [f"f{i:02d}.txt" for i in range(1, 13)]


def open_folder(page: Page, button: str = "file", view: str | None = None) -> Dialog:
    d = Dialog(page, button).open()
    d.after_listing(lambda: d.dblclick_row("folder"))
    if view:
        d.find(f"#sF-btn-{view}").click()
    return d


def files_in_order(d: Dialog) -> list[str]:
    return d.row_names(".sF-fileList > .sF-file")


def known_bug(bug: str):
    return pytest.mark.xfail(reason=f"known bug: {KNOWN_BUGS[bug]}", strict=True)


@pytest.mark.parametrize("view", [
    "detail", "list",
    pytest.param("icon", marks=known_bug("icon-right-stops")),
])
def test_arrows_walk_every_file_and_stop_at_the_ends(app: Page, view):
    d = open_folder(app, view=view)
    order = d.row_names()
    d.click_row(order[0])
    forward = "ArrowRight" if view == "icon" else "ArrowDown"
    back = "ArrowLeft" if view == "icon" else "ArrowUp"
    seen = [d.selected_rows()[0]]
    for _ in range(len(order) + 2):
        app.keyboard.press(forward)
        seen.append(d.selected_rows()[0])
    # Every entry, in display order, then it stays on the last one.
    assert seen[: len(order)] == order
    assert seen[-1] == order[-1]
    for _ in range(len(order) + 2):
        app.keyboard.press(back)
    assert d.selected_rows() == [order[0]]


def test_arrow_with_nothing_selected_starts_at_the_first_entry(app: Page):
    d = open_folder(app)
    app.keyboard.press("ArrowDown")
    assert d.selected_rows() == [d.row_names()[0]]


def test_left_and_right_do_nothing_in_detail_view(app: Page):
    d = open_folder(app, view="detail")
    d.click_row("f05.txt")
    app.keyboard.press("ArrowRight")
    app.keyboard.press("ArrowLeft")
    assert d.selected_rows() == ["f05.txt"]


def test_icon_view_up_and_down_move_by_a_whole_row(app: Page):
    d = open_folder(app, view="icon")
    per_row = d.js(
        "var items = m.find('.sF-fileList').children().slice(1);"
        "var top = $(items[0]).position().top;"
        "return items.filter(function(){ return $(this).position().top === top; }).length;"
    )
    order = d.row_names()
    if per_row >= len(order):
        pytest.skip("every icon fits on one row at this window size")
    d.click_row(order[0])
    app.keyboard.press("ArrowDown")
    assert d.selected_rows() == [order[per_row]]
    app.keyboard.press("ArrowUp")
    assert d.selected_rows() == [order[0]]


def test_shift_arrow_extends_the_selection_past_the_tenth_file(app: Page):
    d = open_folder(app, view="detail")
    d.click_row("f08.txt")
    for _ in range(4):
        app.keyboard.press("Shift+ArrowDown")
    assert d.selected_rows() == ["f08.txt", "f09.txt", "f10.txt", "f11.txt", "f12.txt"]
    # And back again: the anchor stays at f08.
    for _ in range(6):
        app.keyboard.press("Shift+ArrowUp")
    assert d.selected_rows() == ["f06.txt", "f07.txt", "f08.txt"]


def test_a_plain_arrow_after_a_range_continues_from_its_end(app: Page):
    d = open_folder(app, view="detail")
    d.click_row("f02.txt")
    app.keyboard.press("Shift+ArrowDown")
    app.keyboard.press("Shift+ArrowDown")
    app.keyboard.press("ArrowDown")
    assert d.selected_rows() == ["f05.txt"]


def test_shift_click_range_across_the_tenth_file(app: Page):
    d = open_folder(app)
    d.click_row("f09.txt")
    d.click_row("f11.txt", ["Shift"])
    assert d.selected_rows() == ["f09.txt", "f10.txt", "f11.txt"]
    d.click_row("f02.txt", ["Shift"])
    assert d.selected_rows() == FILES[1:9]


def test_shift_arrow_in_a_single_select_dialog_moves_rather_than_extends(app: Page):
    d = Dialog(app, "fileIcon").open()
    d.after_listing(lambda: d.dblclick_row("folder"))
    d.click_row("f01.txt")
    app.keyboard.press("Shift+ArrowRight")
    assert len(d.selected_rows()) == 1


def test_arrows_in_the_save_dialog_copy_the_name_into_the_filename_box(app: Page):
    d = open_folder(app, button="save")
    d.click_row("f01.txt")
    expect(d.find("input.sF-filename")).to_have_value("f01")
    app.keyboard.press("ArrowDown")
    expect(d.find("input.sF-filename")).to_have_value("f02")


def test_arrows_are_ignored_while_typing_a_filename(app: Page):
    d = open_folder(app, button="save")
    d.click_row("f01.txt")
    box = d.find("input.sF-filename")
    box.click()
    app.keyboard.press("ArrowDown")
    assert d.selected_rows() == ["f01.txt"]


def test_enter_on_a_folder_opens_it(app: Page):
    d = Dialog(app, "file").open()
    d.click_row("folder")
    d.after_listing(lambda: app.keyboard.press("Enter"))
    assert d.location() == ["", "folder"]


def test_enter_in_the_save_dialog_on_a_folder_opens_it(app: Page):
    d = Dialog(app, "save").open()
    d.click_row("folder")
    d.after_listing(lambda: app.keyboard.press("Enter"))
    assert d.location() == ["", "folder"]


# --- folder tree ------------------------------------------------------------------


def selected_folder(d: Dialog) -> str:
    return d.js("return m.find('.sF-dirList .selected > .sF-file-name').text().trim();")


def test_tree_arrows_with_nothing_selected_start_at_the_root(app: Page):
    d = Dialog(app, "dir").open()
    d.after_listing(lambda: app.keyboard.press("ArrowDown"))
    assert selected_folder(d) == "data"


def test_tree_down_and_up_walk_siblings_children_and_back(app: Page):
    d = Dialog(app, "dir").open()
    d.highlight_root()
    order = []
    for _ in range(3):
        d.after_listing(lambda: app.keyboard.press("ArrowDown"))
        order.append(selected_folder(d))
    assert order == ["empty", "folder", "locked"]
    d.after_listing(lambda: app.keyboard.press("ArrowUp"))
    assert selected_folder(d) == "folder"
    d.after_listing(lambda: app.keyboard.press("ArrowUp"))
    d.after_listing(lambda: app.keyboard.press("ArrowUp"))
    assert selected_folder(d) == "data"


def test_tree_right_expands_and_left_collapses(app: Page):
    d = Dialog(app, "dir").open()
    d.highlight("folder")
    d.after_listing(lambda: app.keyboard.press("ArrowRight"))
    expect(d.tree_node("folder")).to_have_class(re.compile("expanded"))
    # Down from an expanded folder goes to its first child.
    d.after_listing(lambda: app.keyboard.press("ArrowDown"))
    assert selected_folder(d) == "sub"
    # Down from the last child goes to the next sibling of its parent.
    d.after_listing(lambda: app.keyboard.press("ArrowDown"))
    assert selected_folder(d) == "locked"
    # Up into an expanded sibling lands on its last child.
    d.after_listing(lambda: app.keyboard.press("ArrowUp"))
    assert selected_folder(d) == "sub"
    # Left from a child selects the parent and collapses it.
    d.after_listing(lambda: app.keyboard.press("ArrowLeft"))
    assert selected_folder(d) == "folder"
    expect(d.tree_node("folder")).not_to_have_class(re.compile("expanded"))


def test_tree_left_on_an_expanded_folder_collapses_it(app: Page):
    d = Dialog(app, "dir").open()
    d.highlight("folder")
    d.after_listing(lambda: app.keyboard.press("ArrowRight"))
    d.after_listing(lambda: app.keyboard.press("ArrowLeft"))
    expect(d.tree_node("folder")).not_to_have_class(re.compile("expanded"))
    assert selected_folder(d) == "folder"


# --- two dialogs open at once --------------------------------------------------------


@known_bug("arrows-two-dialogs")
def test_arrows_move_the_selection_in_the_topmost_dialog_only(app: Page):
    bottom = Dialog(app, "file").open()
    bottom.click_row("a.txt")
    # Open a second dialog on top without closing the first.
    app.evaluate("() => $('#save').trigger('click')")
    top = Dialog(app, "save")
    app.wait_for_function("() => { var m = $('#save').data('modal'); return !!m && m.data('currentData') !== undefined; }")
    top.click_row("b.csv")
    app.keyboard.press("ArrowDown")
    assert top.selected_rows() == ["c.R"]
    assert bottom.selected_rows() == ["a.txt"], "the dialog underneath must not move"
