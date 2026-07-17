# Stack upkeep: keeping the serving stack current, tracked, and simple

Status: SCAFFOLD - to be fleshed out and planned in a dedicated session. Captured 2026-07-17 during the llamacpp-serving eval so the intent is not lost.

## Why

- The stack has four moving parts on independent release cadences - the stock llama.cpp build, Ollama, Open WebUI, and this repo's Modelfiles/pinned GGUF snapshots - plus environment facts (CUDA version, driver, WSL2 disk). Today each is pinned ad hoc and drift is discovered by accident (example: AGENTS.md recorded Ollama 0.31.1 while 0.31.2 is actually installed; llama.cpp upstream moved ~200 build tags past the local b9860 in two weeks).
- Updates carry real, documented risk here: #24795-class regressions in llama.cpp, the CUDA 13.2 Gemma-corruption mandate, the MTP x CUDA-graphs crash, chat-template guards in community GGUFs. So "always update" and "never update" are both wrong; the repo needs a deliberate, simple upkeep loop with a verification gate per component.

## Inputs for the planning session

- The 2026-07-17 version-delta summary (appendix below once landed): what b9860->latest, Ollama 0.31.2->0.32.x, and the Open WebUI delta mean for this repo.
- The llamacpp-serving eval's watch items and pin-and-recheck rule (re-verify the Gemma MTP load check after every llama.cpp rebuild): [docs/history/2026-07-17-llamacpp-eval.md](../../docs/history/2026-07-17-llamacpp-eval.md).
- Repo conventions: AGENTS.md (pinned snapshot policy, keep-set policy, serving env constraints).

## Open questions for the planning session

- What is "the environment" to track, concretely: a single doc? a machine-readable manifest (component versions, build hashes, CUDA/driver, key env vars)? where does it live and what updates it?
- Update cadence and trigger: scheduled check, on-need, or watch-item-driven (e.g. a #24942 merge should prompt a llama.cpp rebuild)?
- Per-component verification gate: what is the minimum check before an update is trusted (Gemma MTP load check for llama.cpp; parity spot-bench for Ollama; template gate for new GGUFs; DB backup + smoke for Open WebUI)?
- What stays pinned by policy (GGUF snapshots - pinned on purpose per AGENTS.md) vs what tracks latest?
- Simplicity boundary: prefer checklists and the existing benchmark suites over any new machinery or services.

## Acceptance (draft - firm up at planning)

- A written upkeep procedure in docs/ plus whatever minimal tracking file it needs; each component has a named verify step; no new background services.

## Appendix: 2026-07-17 version-delta snapshot

Produced by a 3-agent research pass (sonnet, medium effort; sources cited per claim; llama.cpp examined via local `git fetch` + log, working tree kept at b9860).

### llama.cpp: local b9860 (fdb1db877) vs upstream b10064 - 204 commits behind

- **The tracked Gemma MTP fixes have NOT merged**: no commit touches `src/models/gemma4-assistant.cpp` in the range, and #24942/#24795/#24443 appear nowhere in origin/master's full history. Upgrading would not resolve the headline issue; the b9860 pin stays correct.
- Speculative-decoding internals churned in 4 commits (incl. draft-simple crash fix 956973c76/#25720) - **re-smoke `--spec-type draft-mtp` before adopting any newer build** (the eval's pin-and-recheck rule).
- llama-cli was rewritten to an HTTP client (c264f65ff/#24948) - main compat risk if scripts call llama-cli (this repo's lane uses llama-server + curl, unaffected).
- Small wins in a future rebuild: Anthropic conversion fix for image blocks in tool_result (6b4dc2116/#22536, relevant to Claude Code tool loops); server accepts null sampling params (4f37f5197/#25538). No change to sampling-default injection semantics found.
- Nothing addresses the Ada/arch-89 CUDA crashes tracked here (only Volta/Turing graphs enablement, 3f08ef2c5/#25749).
- Verdict (agent): wait / no urgent pull.

### Ollama: installed 0.31.2 vs v0.32.1 (2026-07-16)

- Small product release (20 commits, 89 files): interactive agent CLI/TUI (bare `ollama` now launches an agent experience, PR #17017), launch-flow renames/warnings, Gemma4 chat-template/tool-calling fixes (Go parser/renderer level, 8a0016f82/#17182), Apple-MLX-only MTP cache fixes.
- **Does not bump vendored llama.cpp and touches no CUDA/GGML/vendor paths** (file-diff scan; agent flags this as strong-but-not-line-audited evidence): the 2026-07-17 illegal-memory-access crash and the MTP x graphs crash are NOT addressed by 0.32.x.
- No API/Modelfile/keep-alive changes detected. One real benefit for this box: the Gemma4 tool-calling/template fidelity fixes (gemma is the agentic daily driver).
- **Upgrade caution specific to this setup**: claude-local drives Ollama via `ollama launch claude`; v0.32.0 reworks the launch flow (renames/warnings) - verify `ollama launch claude` still behaves before/after any upgrade.
- Verdict (agent): low-risk, low-benefit upgrade; not mid-eval, and not the fix for the tracked crashes.

### Open WebUI: installed 0.10.2 == latest v0.10.2 (2026-07-01)

- No delta. (Agent honestly flags it did not audit the historical 0.9.6 -> 0.10.2 jump; out of scope for installed-vs-latest.)

### Doc drift found while checking

- AGENTS.md records Ollama 0.31.1; the box runs 0.31.2. Fix the recorded version as part of this feature's tracking-file work.
