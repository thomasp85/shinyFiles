# Tests

shinyFiles has three layers of tests. All of them run from a source checkout.

| Layer | Where | Runs on CRAN | Measures |
|---|---|---|---|
| R unit and server tests | `testthat/` | yes | R coverage (covr) |
| R browser tests (shinytest2) | `testthat/test-*-e2e.R`, `test-catalogue-guard.R` | no | |
| Playwright (Python) | `playwright/` | no (not in the package tarball) | `shinyFiles.js` coverage |

## Running

Everything, in order, with a report:

```sh
./scripts/run_tests.sh              # stops at the first failing stage
./scripts/run_tests.sh --continue   # runs every stage
```

This writes `Documentation/.staging/TestReport.md` and `test_metadata.json`
(gitignored). The report records who ran the tests, the commit, the R and
Python package versions, the output of each stage, and both coverage figures.
Set `RSCRIPT` to choose an R, and `BROWSERS` to choose the Playwright browsers
(default `chromium firefox`).

One layer at a time:

```r
# R tests, browser tests included
Sys.setenv(NOT_CRAN = "true")
devtools::test()

# R coverage
covr::package_coverage(type = "tests")
```

```sh
# Playwright
cd tests/playwright
uv sync
uv run playwright install chromium firefox   # once
uv run pytest --browser chromium --browser firefox
```

The browser tests call `skip_on_cran()`, so they only run with
`NOT_CRAN=true`. They need shinytest2, chromote and a Chrome or Chromium
binary, and skip themselves if any is missing.

## The input catalogue

`testthat/inputs-catalogue.csv` lists every control in the three dialogs, one
row per control per dialog, each naming a check. Both browser suites drive
every row:

- `test-catalogue-e2e.R` (shinytest2) checks the result on the page and the
  value Shiny receives.
- `playwright/test_catalogue.py` does the same with real mouse and keyboard
  input, in Chromium, Firefox and WebKit.

`test-catalogue-guard.R` opens each dialog, lists the controls it actually
renders, and fails if one has no row. Adding a control to `shinyFiles.js`
therefore means adding a catalogue row and a check for it.

## Coverage

R coverage comes from the in-process tests: the unit tests, and the server
tests that drive the dialogs through `testServer()` with a scripted client
(`helper-dialog.R`). covr can't count code that only runs inside the app
process a shinytest2 test starts: that process is killed rather than exiting,
so its trace is lost. The browser tests are therefore there for the
JavaScript, and `shinyFiles.js` coverage comes from Playwright's Chromium run.

## Test files

### R: unit and server (`testthat/`)

| File | What it tests |
|---|---|
| `test-buttons.R` | The six button and link builders: every argument, plus markup snapshots |
| `test-parse.R` | `parseFilePaths()`, `parseDirPath()`, `parseSavePath()` |
| `test-getvolumes.R` | `getVolumes()` on macOS, Linux, Windows (WMIC and PowerShell) and an unknown OS, using mocks |
| `test-filechoose-server.R` | `shinyFileChoose()`'s server side: defaults, navigation, filters, typed paths, refresh, `updateFreq`, modules |
| `test-filesave-server.R` | `shinyFileSave()`'s server side, including saving into a folder that doesn't exist yet and creating folders |
| `test-filesave-reactive-args.R` | Reactive values passed through `...` to `shinyFileSave()` |
| `test-dir-cache.R` | The folder chooser's listing cache, when it is invalidated, and the background empty-folder check |
| `test-dir-listing.R` | Folder listings against an independent `list.files()` check: symlinks, odd names, hidden files, unreadable and vanished folders, and how many folders are read |
| `test-typed-path.R` | Resolving text typed into the path box against the roots |
| `test-restrictions.R` | What `restrictions` hides |
| `test-edge-cases.R` | Error branches and unusual input in the listing helpers |
| `test-misc.R` | `formatFiletype()`, `getSession()`, `.onLoad()`, `shinyFilesExample()` |

### R: browser (`testthat/`, shinytest2)

| File | What it tests |
|---|---|
| `test-catalogue-guard.R` | Every rendered control has a catalogue row |
| `test-catalogue-e2e.R` | Every catalogue row |
| `test-typed-path-e2e.R` | The path box in the file and folder choosers, and the loading overlay with a deliberately slow app |
| `test-recent-e2e.R` | The "Recent" folders list |
| `test-dir-tree-e2e.R` | Expand arrows disappearing from empty folders |
| `test-multi-modal-e2e.R` | Two dialogs open at once |

### Helpers

| File | What it provides |
|---|---|
| `helper-browser.R` | `skipUnlessBrowser()`, `writeTestApp()` (which loads this checkout under `devtools::test()`), `newApp()`, `openDialogFor()`, `expectNoAppErrors()`, browser cleanup |
| `helper-dialog.R` | `withFileDialog()`: a scripted client for the file and save dialogs under `testServer()` |
| `helper-catalogue.R` | The catalogue app and its file tree, shared with Playwright |

### Playwright (`playwright/`)

See [playwright/README.md](playwright/README.md).

| File | What it tests |
|---|---|
| `test_catalogue.py` | Every catalogue row, with real input |
| `test_keyboard.py` | Arrow keys in each view, Shift ranges, the folder tree, Enter, two dialogs open at once |
| `test_dialogs.py` | File sizes, history and sort order kept, recent folders across reloads, warnings, the loading overlay |

## Isolation

The dialogs keep no state on disk. Every root a test uses is a fresh
temporary folder. The browser-side state (localStorage, and what each button
remembers between openings) starts clean for each test: every Playwright test
and shinytest2 app gets a fresh browser profile, and the catalogue tests reset
the page between rows. So there is no `TESTING` switch to set.
