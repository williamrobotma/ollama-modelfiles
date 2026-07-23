# 2026-07-23: chat-template refresh execution

Executes the `chat-template-refresh` spec bundle (research captured 2026-07-17).

- Environment: stock llama-server b9860 (fdb1db877), WSL2 + RTX 4070.
- Spec claims re-verified live against the HF API before acting: all confirmed except qwopus (below).

## Full-fleet guard scan

Method: `head -c 30000000 <gguf> | grep -c 'System message must be at the beginning'` on every unique GGUF referenced by the qwen3.5 / qwen3.6 / qwopus3.5 Modelfiles.

- Guarded: 4 GGUFs covering 6 canonical model names (thin aliases excluded).
  - unsloth Qwen3.5-9B non-MTP (`9b-coding-ud-q4-k-xl`).
  - OBLITERATUS Qwen3.6-27B (one GGUF serves both `27b-obliterated*` models).
  - mradermacher Qwen3.5-Queen-27B (one GGUF serves both `queen-27b-*` models).
  - Jackrong Qwopus3.5-9B-coder.
- New vs the spec: qwopus was listed clean - an `ollama show --template` (Go conversion) misread.
- Clean: all unsloth `merged_system` builds (Qwen3.6-27B and 35B-A3B plain+MTP, Qwen3.5-9B-MTP).

## froggeric validation on b9860

Template: `froggeric/Qwen-Fixed-Chat-Templates` v21.3, snapshot `23a40b0b`, Apache-2.0.

- Offline: froggeric's `scripts/test_v21.py` 9/9 pass (Python jinja2 3.1.6; includes a mid-conversation system test).
- Serving: llama-server `-ngl 0 -c 8192 --jinja`, port 11438.
- Probes: multi-system `/v1/chat/completions`; tool loop with a mid-conversation system message; multi-block system `/v1/messages`.

| GGUF | embedded template | + froggeric |
|---|---|---|
| unsloth Qwen3.5-9B non-MTP | 400 (guard) | 200; tool loop 200; `/v1/messages` 200 |
| Qwopus3.5-9B-coder | 400 (guard) | 200 |
| OBLITERATUS Qwen3.6-27B | not probed (grep: guarded) | 200 |
| Qwen3.5-Queen-27B | not probed (grep: guarded) | 200 |

- The `/v1/messages` 200 is the once-per-build Anthropic immunity check.
- The tool-loop answer honored the mid-conversation system reminder ("answer in one sentence").

## Gemma QAT re-pull

Re-pinned all three QAT Modelfile sets to the 2026-07-17 "Added Gemma official chat template update" snapshots.

- Commits confirmed from metadata before download (the spec's free check).
  - 12B `980b060c40a8539ac159e0501a3e0f66a6365af3`.
  - 26B-A4B `7b92b5b28818151e8669af2e45e88d6086f490dd`.
  - 31B `43cc1aeb31adf47ec06a854507ce552cd9862e6f`.
- Upstream provenance: Google's fix is `google/gemma-4-12B-it` PR #35 (2026-07-15), unchanged upstream through 2026-07-23.
- Drafter load checks on the new snapshots - all three pairs load and generate:
  - 12B, GPU graphs-on 16k: 129 tok/s, 66/85 drafts accepted; `<|think|>` system prompt yields thinking content.
  - 26B-A4B, CPU: 65/88 accepted.
  - 31B, CPU (first test of this pair): 63/95 accepted.
  - All three log a non-fatal `[spec] failed to measure draft model memory` warning; drafting demonstrably works.

## Currency check (2026-07-23)

Web/GitHub sweep for changes since the spec's 2026-07-17 capture.

- llama.cpp: b10092 latest; #24795 / #24443 still open; fix PR #24942 unmerged, zero reviews. The b9860 pin stands.
  - New watch items filed in `specs/llamacpp-migration`: #25873 (second Gemma MTP crash mechanism), #25986 (`peg-gemma4` parser vs long tool-call args).
- Gemma re-pin risk: none found - no rollback and no regression reports against the 2026-07-17 snapshots.
  - unsloth announcement: "increased tool call accuracy by up to 10%".
- froggeric: no version past 21.3; system-message and Anthropic-thinking handling have no open bugs.
  - Open tool-call regression reports exist (#55 / #56 / #64; #56 is on b9860); watch note filed with the deferred quality A/B in tasks.md.
- Qwen: guard unchanged; maintainer says it is by design ("change their role to user"). No official fix coming.
- Ollama 0.32.2 (2026-07-20) bumps its vendored llama.cpp - note for stack-upkeep's next snapshot.

## Provenance and validity

- Single box, single session; probes n=1 per cell.
- The template gate is deterministic parse-time behavior: n=1 is conclusive for 400-vs-200, and says nothing about output quality.
- Ollama models deliberately not rebuilt from the new snapshots.
  - Ollama never executes the GGUF Jinja, and its Gemma DRAFT lane is the crashing path being retired.
  - Installed Ollama Gemma models stay on the old snapshots until the migration removes them.
- HF and GitHub facts fetched live this session by verification and currency fan-outs.
