#!/usr/bin/env python3
"""Summarize a benchmark-results/<timestamp>/ tree.

Reads the run-*.log verbose footers and run-*.time files the harness writes
(does not re-run anything) and prints, per model x prompt x runtime profile:
  - generation throughput mean +/- stdev over reps (the D "tighten stats" ask),
    broken out per prompt rather than averaged across prompts;
  - coarse output-sanity flags (the C "correctness" ask).

Throughput uses the `eval rate:` footer line; the prompt-processing
`prompt eval rate:` line is deliberately excluded (averaging the two together
was the bug in the first hand-rolled pass). Output-sanity is intentionally
coarse: the run logs are `ollama run --verbose` TTY output (cursor/escape
codes, partial-line rewrites), so fine-grained corruption detection on them is
unreliable -- we flag only signals that survive that noise (nonzero exit,
empty generation) and surface the eval_count range so truncation is visible.
"""
from __future__ import annotations

import argparse
import re
import statistics
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path

ANSI = re.compile(r"\x1b\[[0-9;?]*[a-zA-Z]")


@dataclass
class Run:
    profile: str
    model: str
    prompt: str
    rep: int
    eval_rate: float | None  # generation tokens/s
    eval_count: int | None
    wall_s: float | None
    exit_status: int | None

    @property
    def empty(self) -> bool:
        return self.eval_count == 0


def _footer(log: Path) -> tuple[float | None, int | None]:
    """(eval_rate tok/s, eval_count) from the verbose footer; None if absent."""
    rate = count = None
    for raw in log.read_text(errors="replace").splitlines():
        line = ANSI.sub("", raw).strip()
        if line.startswith("eval rate:"):
            m = re.search(r"([\d.]+)\s*tokens/s", line)
            rate = float(m.group(1)) if m else None
        elif line.startswith("eval count:"):
            m = re.search(r"(\d+)", line)
            count = int(m.group(1)) if m else None
    return rate, count


def _time(tf: Path) -> tuple[float | None, int | None]:
    """(wall_clock_seconds, exit_status) from a /usr/bin/time -o file."""
    wall = status = None
    if tf.exists():
        for line in tf.read_text().splitlines():
            key, _, val = line.partition("=")
            if key == "wall_clock_seconds":
                wall = float(val)
            elif key == "exit_status":
                status = int(val)
    return wall, status


def collect(root: Path) -> list[Run]:
    """One Run per <profile>/<model>/<prompt>/run-N.{log,time} pair."""
    runs: list[Run] = []
    for log in sorted(root.glob("*/*/*/run-*.log")):
        prompt_dir = log.parent
        rep = int(log.stem.split("-")[1])
        rate, count = _footer(log)
        wall, status = _time(prompt_dir / f"run-{rep}.time")
        runs.append(Run(
            profile=prompt_dir.parents[1].name,
            model=prompt_dir.parents[0].name,
            prompt=prompt_dir.name,
            rep=rep, eval_rate=rate, eval_count=count,
            wall_s=wall, exit_status=status,
        ))
    return runs


def _mean_sd(xs: list[float | None]) -> tuple[float | None, float, int]:
    vals = [x for x in xs if x is not None]
    if not vals:
        return None, 0.0, 0
    sd = statistics.stdev(vals) if len(vals) > 1 else 0.0
    return statistics.mean(vals), sd, len(vals)


def report(runs: list[Run]) -> None:
    profiles = sorted({r.profile for r in runs})  # graphs-off < graphs-on
    # (model, prompt) -> profile -> [runs]
    groups: dict[tuple[str, str], dict[str, list[Run]]] = defaultdict(
        lambda: defaultdict(list))
    for r in runs:
        groups[(r.model, r.prompt)][r.profile].append(r)

    print("Generation throughput (tok/s, mean +/- sd over reps), per prompt")
    header = f"{'model':38} {'prompt':10}" + "".join(f" {p:>16}" for p in profiles)
    if len(profiles) == 2:
        header += f" {'delta%':>8}"
    print(header)
    for model, prompt in sorted(groups):
        means: dict[str, float | None] = {}
        row = f"{model:38} {prompt:10}"
        for p in profiles:
            m, sd, n = _mean_sd([r.eval_rate for r in groups[(model, prompt)].get(p, [])])
            means[p] = m
            cell = f"{m:.2f}+/-{sd:.2f}(n{n})" if m is not None else "-"
            row += f" {cell:>16}"
        if len(profiles) == 2 and all(means[p] is not None for p in profiles):
            off, on = means[profiles[0]], means[profiles[1]]
            row += f" {(on - off) / off * 100:+7.1f}%"
        print(row)

    # Coarse output-sanity (see module docstring for why it is coarse).
    flagged = [r for r in runs if r.exit_status not in (0, None) or r.empty]
    counts = [r.eval_count for r in runs if r.eval_count is not None]
    print(f"\nOutput sanity (coarse): {len(runs)} runs, {len(flagged)} flagged")
    if counts:
        print(f"  eval_count range: {min(counts)}-{max(counts)} tokens "
              f"(runs pinned near num_predict => truncation)")
    for r in flagged:
        why = "nonzero exit" if r.exit_status not in (0, None) else "empty output"
        print(f"  FLAG [{why}] {r.profile}/{r.model}/{r.prompt} run-{r.rep} "
              f"(exit={r.exit_status}, eval_count={r.eval_count})")
    if not flagged:
        print("  no nonzero exits or empty generations")


def main(argv: list[str] | None = None) -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("dirs", nargs="*", type=Path,
                    help="results dirs (default: all under ./benchmark-results)")
    args = ap.parse_args(argv)

    dirs = args.dirs
    if not dirs:
        base = Path("benchmark-results")
        dirs = sorted(d for d in base.glob("*") if d.is_dir()) if base.is_dir() else []
    if not dirs:
        sys.exit("no results dirs found (pass a benchmark-results/<timestamp> path)")

    for d in dirs:
        runs = collect(d)
        print(f"\n===== {d} ({len(runs)} runs) =====")
        if runs:
            report(runs)
        else:
            print("  (no run logs found)")


if __name__ == "__main__":
    main()
