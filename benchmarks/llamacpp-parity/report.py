#!/usr/bin/env python3
"""Post-run report for the llamacpp-parity suite.

Reads a benchmark-results/<timestamp> directory produced by run.sh and prints
decode tok/s mean/stdev per profile/model/prompt (measured runs only, warmup
excluded), MTP draft acceptance where present, and the two ratio views:
llamacpp-vs-ollama per model, and mtp-vs-plain per engine. Stdlib only.
"""
import json
import re
import statistics
import sys
from pathlib import Path

EVAL_RATE = re.compile(r"^eval rate:\s+([0-9.]+) tokens/s", re.M)
EVAL_COUNT = re.compile(r"^eval count:\s+([0-9]+) token", re.M)


def ollama_run(log: Path):
    text = log.read_text(errors="replace")
    rates = EVAL_RATE.findall(text)
    counts = EVAL_COUNT.findall(text)
    if not rates:
        return None
    return {
        "rate": float(rates[-1]),
        "tokens": int(counts[-1]) if counts else None,
        "draft_n": None,
        "draft_accepted": None,
    }


def llama_run(js: Path):
    try:
        c = json.loads(js.read_text())
    except (json.JSONDecodeError, OSError):
        return None
    t = c.get("timings") or {}
    if t.get("predicted_per_second") is None:
        return None
    return {
        "rate": t["predicted_per_second"],
        "tokens": t.get("predicted_n"),
        "draft_n": t.get("draft_n"),
        "draft_accepted": t.get("draft_n_accepted"),
    }


def collect(results_dir: Path):
    """-> {(profile, label, prompt): [run dicts]}"""
    out = {}
    for profile_dir in sorted(p for p in results_dir.iterdir() if p.is_dir() and p.name != "prompts"):
        for label_dir in sorted(p for p in profile_dir.iterdir() if p.is_dir()):
            for prompt_dir in sorted(p for p in label_dir.iterdir() if p.is_dir()):
                runs = []
                for n in range(1, 100):
                    js = prompt_dir / f"run-{n}.json"
                    log = prompt_dir / f"run-{n}.log"
                    if js.exists():
                        run = llama_run(js)
                    elif log.exists():
                        run = ollama_run(log)
                    else:
                        break
                    if run:
                        runs.append(run)
                if runs:
                    out[(profile_dir.name, label_dir.name, prompt_dir.name)] = runs
    return out


def mean_rate(runs):
    return statistics.mean(r["rate"] for r in runs)


def main():
    if len(sys.argv) != 2:
        sys.exit(f"usage: {sys.argv[0]} benchmark-results/<timestamp>")
    results_dir = Path(sys.argv[1])
    data = collect(results_dir)
    if not data:
        sys.exit(f"no completed runs found under {results_dir}")

    print(f"{'profile':<20} {'model':<14} {'prompt':<10} {'n':>2} "
          f"{'tok/s':>8} {'stdev':>7} {'gen_tok':>8} {'accept':>7}")
    for (profile, label, prompt), runs in sorted(data.items()):
        rates = [r["rate"] for r in runs]
        stdev = statistics.stdev(rates) if len(rates) > 1 else 0.0
        tokens = [r["tokens"] for r in runs if r["tokens"]]
        drafted = sum(r["draft_n"] or 0 for r in runs)
        accepted = sum(r["draft_accepted"] or 0 for r in runs)
        accept = f"{accepted / drafted:.3f}" if drafted else "-"
        flag = " (short)" if tokens and min(tokens) < 64 else ""
        print(f"{profile:<20} {label:<14} {prompt:<10} {len(rates):>2} "
              f"{statistics.mean(rates):>8.1f} {stdev:>7.2f} "
              f"{(statistics.mean(tokens) if tokens else 0):>8.0f} {accept:>7}{flag}")

    profiles = sorted({k[0] for k in data})
    print("\nllamacpp vs ollama (same model+prompt, ratio of mean decode tok/s):")
    for (profile, label, prompt) in sorted(data):
        if "llamacpp" not in profile:
            continue
        for other in profiles:
            base = data.get((other, label, prompt))
            if other == profile or base is None or "llamacpp" in other:
                continue
            ratio = mean_rate(data[(profile, label, prompt)]) / mean_rate(base)
            print(f"  {label:<14} {prompt:<10} {profile} / {other} = {ratio:.2f}x")

    print("\nmtp vs plain (same engine+prompt, ratio of mean decode tok/s):")
    for (profile, label, prompt) in sorted(data):
        if not label.endswith("-mtp"):
            continue
        base = data.get((profile, label[: -len("-mtp")], prompt))
        if base:
            ratio = mean_rate(data[(profile, label, prompt)]) / mean_rate(base)
            print(f"  {profile:<20} {label:<14} {prompt:<10} = {ratio:.2f}x")


if __name__ == "__main__":
    main()
