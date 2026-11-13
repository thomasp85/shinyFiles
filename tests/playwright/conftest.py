"""Shared fixtures for the shinyFiles Playwright suite.

One R process serves the catalogue app (run-app.R) for the whole session.
Each test gets a fresh browser context, so localStorage and the state a
button keeps between openings start clean.

On Chromium, JS coverage of shinyFiles.js is collected for every test through
the DevTools protocol and written as LCOV when the session ends (see
jscoverage.py).
"""

from __future__ import annotations

import os
import shutil
import socket
import subprocess
import tempfile
import time
import urllib.request
from pathlib import Path

import pytest

import jscoverage as jscov

HERE = Path(__file__).resolve().parent
RSCRIPT = os.environ.get("RSCRIPT") or shutil.which("Rscript") or "Rscript"


def _free_port() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


@pytest.fixture(scope="session")
def fixture_dir():
    d = Path(tempfile.mkdtemp(prefix="sf-pw-"))
    yield d / "tree"
    # The locked folder is read-only; make it removable again.
    for p in d.rglob("*"):
        if p.is_dir():
            p.chmod(0o755)
    shutil.rmtree(d, ignore_errors=True)


@pytest.fixture(scope="session")
def app_url(fixture_dir):
    port = _free_port()
    log = open(fixture_dir.parent / "app.log", "w")
    proc = subprocess.Popen(
        [RSCRIPT, str(HERE / "run-app.R"), str(port), str(fixture_dir)],
        stdout=log, stderr=subprocess.STDOUT,
    )
    url = f"http://127.0.0.1:{port}/"
    deadline = time.time() + 60
    while time.time() < deadline:
        if proc.poll() is not None:
            raise RuntimeError(f"app exited early; see {log.name}:\n" + Path(log.name).read_text())
        try:
            urllib.request.urlopen(url, timeout=1)
            break
        except OSError:
            time.sleep(0.5)
    else:
        proc.kill()
        raise RuntimeError("app did not start within 60 s")
    yield url
    proc.terminate()
    try:
        proc.wait(10)
    except subprocess.TimeoutExpired:
        proc.kill()
    log.close()


@pytest.fixture(scope="session")
def js_coverage():
    collector = jscov.Collector(script_suffix="/sF/shinyFiles.js")
    yield collector
    out = HERE / "coverage"
    if collector.has_data():
        source = HERE.parent.parent / "inst" / "www" / "shinyFiles.js"
        pct = collector.write_lcov(source, out / "lcov.info", repo_path="inst/www/shinyFiles.js")
        (out / "summary.txt").write_text(f"shinyFiles.js line coverage: {pct:.1f}%\n")
        print(f"\nshinyFiles.js line coverage: {pct:.1f}% (written to {out})")


@pytest.fixture
def app(page, app_url, browser_name, js_coverage):
    """The catalogue app, loaded and ready, in a fresh context."""
    cdp = None
    if browser_name == "chromium":
        cdp = page.context.new_cdp_session(page)
        cdp.send("Profiler.enable")
        cdp.send("Profiler.startPreciseCoverage", {"callCount": True, "detailed": True})
    errors: list[str] = []
    page.on("pageerror", lambda e: errors.append(str(e)))
    page.goto(app_url)
    page.wait_for_function("window.Shiny && Shiny.shinyapp && Shiny.shinyapp.isConnected()")
    page.wait_for_selector("button#file.shiny-bound-input")
    yield page
    if cdp is not None:
        js_coverage.add(cdp.send("Profiler.takePreciseCoverage")["result"])
    assert errors == [], f"JavaScript errors on the page: {errors}"
