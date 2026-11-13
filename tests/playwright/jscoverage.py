"""Turn V8 precise-coverage data into line coverage for one script.

V8 reports, per function, a list of byte ranges with execution counts. Ranges
nest: a function's first range covers its whole body, later ones mark
sub-blocks (e.g. an untaken branch) with their own count, and the innermost
range covering an offset wins. A line counts as covered if any code character
on it ran, and as uncovered if code on it exists but none of it ran.
"""

from __future__ import annotations

from pathlib import Path


class Collector:
    def __init__(self, script_suffix: str):
        self.suffix = script_suffix
        self.counts: list[int] | None = None
        self.source: str | None = None
        self.n = 0

    def has_data(self) -> bool:
        return self.counts is not None

    def add(self, result: list[dict]) -> None:
        for script in result:
            if not script.get("url", "").endswith(self.suffix):
                continue
            self.n += 1
            # Per-character counts for this run, innermost range wins.
            ranges = [r for fn in script["functions"] for r in fn["ranges"]]
            end = max(r["endOffset"] for r in ranges)
            run = [0] * end
            for r in sorted(ranges, key=lambda r: r["endOffset"] - r["startOffset"], reverse=True):
                run[r["startOffset"]:r["endOffset"]] = [r["count"]] * (r["endOffset"] - r["startOffset"])
            if self.counts is None:
                self.counts = run
            else:
                if len(run) > len(self.counts):
                    self.counts.extend([0] * (len(run) - len(self.counts)))
                for i, c in enumerate(run):
                    self.counts[i] += c

    def line_hits(self, source: str) -> dict[int, int]:
        """1-based line -> hits, for lines containing code."""
        hits: dict[int, int] = {}
        offset = 0
        for lineno, line in enumerate(source.splitlines(keepends=True), start=1):
            code = line.strip()
            if code and not code.startswith("//") and code not in {"{", "}", "});", "})", "};", ")", "]", "});"}:
                seg = self.counts[offset:offset + len(line)] if self.counts else []
                indent = len(line) - len(line.lstrip())
                body = seg[indent:indent + len(line.rstrip()) - indent]
                hits[lineno] = max(body) if body else 0
            offset += len(line)
        return hits

    def write_lcov(self, source_path: Path, out: Path, repo_path: str) -> float:
        source = source_path.read_text()
        hits = self.line_hits(source)
        out.parent.mkdir(parents=True, exist_ok=True)
        covered = sum(1 for h in hits.values() if h > 0)
        lines = [f"SF:{repo_path}"]
        lines += [f"DA:{n},{h}" for n, h in sorted(hits.items())]
        lines += [f"LH:{covered}", f"LF:{len(hits)}", "end_of_record", ""]
        out.write_text("\n".join(lines))
        return 100.0 * covered / max(len(hits), 1)
