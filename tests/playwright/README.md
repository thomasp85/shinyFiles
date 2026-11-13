# Browser tests (Playwright, Python)

These replay every row of `../testthat/inputs-catalogue.csv` with real mouse
and keyboard input, plus keyboard navigation and multi-step dialog behaviour.
They run in Chromium, Firefox and WebKit, and measure line coverage of
`inst/www/shinyFiles.js`.

The R tests in `../testthat/` check the same catalogue from shinytest2 and
give the R coverage. These tests are for the browser side.

## Running

You need R with `pkgload` and this package's dependencies, plus
[uv](https://docs.astral.sh/uv/).

```sh
cd tests/playwright
uv sync
uv run playwright install chromium firefox     # once
uv run pytest --browser chromium --browser firefox
```

Set `RSCRIPT` if `Rscript` isn't on your `PATH`. Each session starts the
catalogue app (`run-app.R`) on a free port, using a fresh copy of the file
tree from `helper-catalogue.R`.

WebKit runs in CI (Ubuntu). Playwright only builds it for Ubuntu and macOS,
so it may not launch on other Linux distributions.

## Files

| File | What it tests |
|---|---|
| `test_catalogue.py` | Every catalogue row, using the same named checks as `test-catalogue-e2e.R` |
| `test_keyboard.py` | Arrow keys in each view, Shift ranges past the tenth file, the folder tree, Enter on folders, two dialogs open at once |
| `test_dialogs.py` | File sizes, history and view/sort kept between openings, recent folders across reloads, the loading overlay |
| `helpers.py` | `Dialog` page helper and the list of known bugs |
| `conftest.py` | Starts the app, gives each test a fresh browser context, collects JS coverage |
| `jscoverage.py` | Converts V8 coverage to LCOV |

## Known bugs

`KNOWN_BUGS` in `helpers.py` lists behaviour the tests pin but which is still
broken. Those tests are marked `xfail(strict=True)`. Once a bug is fixed its
test passes, the strict xfail turns that into a failure, and the entry has to
be removed.

## Coverage

On Chromium, `conftest.py` collects V8 coverage for `shinyFiles.js` from every
test and writes `coverage/lcov.info` and `coverage/summary.txt` when the run
ends. CI uploads it to Codecov under the `js` flag.
