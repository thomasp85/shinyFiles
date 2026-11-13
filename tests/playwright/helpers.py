"""Page helpers shared by the Playwright tests."""

from __future__ import annotations

import csv
import json
from pathlib import Path

from playwright.sync_api import Locator, Page, expect

CATALOGUE = Path(__file__).resolve().parent.parent / "testthat" / "inputs-catalogue.csv"

# Bugs the catalogue pins but that fail on main. A test for one of these is
# expected to fail (xfail, strict), so fixing the bug makes it pass and the
# suite then insists the entry is removed.
KNOWN_BUGS = {
    "icon-right-stops": "in icon view the right arrow stops at the end of the first row",
    "arrows-two-dialogs": "with two dialogs open, arrow keys move neither (moveSelection uses every modal)",
}


def catalogue_rows() -> list[dict]:
    with CATALOGUE.open(newline="") as f:
        return list(csv.DictReader(f))


class Dialog:
    """The topmost open shinyFiles dialog."""

    def __init__(self, page: Page, button_id: str):
        self.page = page
        self.button_id = button_id

    # --- locating ------------------------------------------------------------

    @property
    def modal(self) -> Locator:
        return self.page.locator(".sF-modalContainer.in").last

    def find(self, selector: str) -> Locator:
        return self.modal.locator(selector)

    def js(self, body: str):
        """Evaluate `body` with `m` bound to the dialog's jQuery object."""
        return self.page.evaluate(
            f"() => {{ var m = $('#{self.button_id}').data('modal'); {body} }}"
        )

    # --- state ---------------------------------------------------------------

    def is_open(self) -> bool:
        return self.page.locator(".sF-modalContainer").count() > 0

    def location(self) -> list[str]:
        return self.js(
            "return m.find('.sF-breadcrumps>option').map(function(){ return $(this).val(); })"
            ".toArray().reverse();"
        )

    def row_names(self, sel: str = ".sF-fileList > .sF-file, .sF-fileList > .sF-directory") -> list[str]:
        return self.js(
            f"return m.find({json.dumps(sel)}).map(function(){{ "
            "return $(this).find('.sF-file-name').text().trim(); }).toArray();"
        )

    def selected_rows(self) -> list[str]:
        return self.js(
            "return m.find('.sF-fileList .selected .sF-file-name')"
            ".map(function(){ return $(this).text().trim(); }).toArray();"
        )

    def content_path(self) -> list[str] | None:
        return self.js("return m.data('currentData').contentPath;")

    # --- actions -------------------------------------------------------------

    def open(self) -> "Dialog":
        self.page.click(f"#{self.button_id}")
        self.page.locator(".sF-modalContainer.in").last.wait_for()
        self.page.wait_for_function(
            f"() => {{ var m = $('#{self.button_id}').data('modal');"
            " return !!m && m.data('currentData') !== undefined; }"
        )
        return self

    def _mark_listing(self) -> None:
        # Each listing the server sends replaces the dialog's currentData
        # object, so tag the current one; a new listing is untagged.
        self.js("var d = m.data('currentData'); if (d) d.__seen = true;")

    def after_listing(self, action) -> None:
        """Run `action` and wait for the listing it causes."""
        self._mark_listing()
        action()
        self.page.wait_for_function(
            f"() => {{ var m = $('#{self.button_id}').data('modal');"
            " var d = m && m.data('currentData'); return !!d && d.__seen !== true; }",
            timeout=15000,
        )
        # The dialog redraws from the new listing synchronously after storing it.
        self.page.wait_for_timeout(50)

    def click_row(self, name: str, modifiers: list[str] | None = None) -> None:
        self.find(".sF-fileList").locator(".sF-file, .sF-directory").filter(
            has=self.page.locator(".sF-file-name", has_text=name)
        ).first.click(modifiers=modifiers or [])

    def dblclick_row(self, name: str) -> None:
        self.find(".sF-fileList").locator(".sF-file, .sF-directory").filter(
            has=self.page.locator(".sF-file-name", has_text=name)
        ).first.dblclick()

    def tree_node(self, name: str) -> Locator:
        return self.find(".sF-dirList .sF-directory").filter(
            has=self.page.locator(":scope > .sF-file-name", has_text=name)
        ).first

    def highlight(self, name: str) -> None:
        self.after_listing(lambda: self.tree_node(name).locator(":scope > .sF-file-name").click())

    def highlight_root(self) -> None:
        self.after_listing(
            lambda: self.find(".sF-dirList .sF-directory.root > .sF-file-name").first.click()
        )

    def select_option(self, predicate_js: str) -> None:
        """Choose the breadcrumb option for which `predicate_js` (on `$(this)`) is true."""
        self.js(
            "var s = m.find('.sF-breadcrumps');"
            f"var o = s.find('option').filter(function(){{ return {predicate_js}; }}).first();"
            "s.val(o.val()); o.prop('selected', true);"
        )
        # A real change event from the <select>, as a user picking an option fires.
        self.find("select.sF-breadcrumps").dispatch_event("change")

    def expect_closed(self) -> None:
        expect(self.page.locator(".sF-modalContainer")).to_have_count(0, timeout=10000)

    def output(self, output_id: str) -> str:
        loc = self.page.locator(f"#{output_id}")
        expect(loc).not_to_have_text("", timeout=10000)
        return loc.inner_text().strip()


def shiny_input(page: Page, name: str):
    """The value the browser last sent for input `name`.

    Shiny keys an action button's click count as "<id>:shiny.action", while
    the dialog's own result for the same id is keyed plainly, so look for both.
    """
    return page.evaluate(
        f"() => {{ var v = Shiny.shinyapp.$inputValues; var n = {json.dumps(name)};"
        " return n in v ? v[n] : v[n + ':shiny.action']; }"
    )
