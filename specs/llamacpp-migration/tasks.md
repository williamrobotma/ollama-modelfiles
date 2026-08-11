# Tasks: llamacpp-migration

Planning done 2026-07-23 (spec vetted, plan.md filled). Details and verify steps per item live in `plan.md`.

GPU-loading items are heavy loads: get user confirmation before starting each.

`spec.md` and `plan.md` were locked 2026-07-28 (user directive); the lock was lifted 2026-08-08 - both now carry
dated amendments. Execution deviations and per-item verification notes are recorded here only.

Notation used throughout:

- Status legend: [ ] pending, [x] done.
- `PASS N/N` - N of N trials clean.
- Dated labels `Amended` / `Decided` / `Finding`, written `<Label> YYYY-MM-DD (who):` when both are recorded.

## Pre-flight (2026-07-25)

- [x] Stale b9552 binaries deleted from the llama.cpp repo root; build/bin b9860 is the only one left
- [x] Router preset, alias, and child-env mechanics verified from source on the pin
- [x] Gemma thinking mechanism traced across Google, unsloth, the GGUF template, and llama.cpp source
- [x] Sampling and MTP claims verified against vendor cards; conflicts recorded in docs/parameters.md
- [x] Findings written to docs/history/2026-07-25-llamacpp-preflight.md

## Fleet reduction (2026-07-27)

The set of kept models narrowed at the execution review (spec execution revisions).
Deletion was pulled forward from the Phase 4 purge.
Fleet: 17 configs + 6 aliases.

- [x] 8 Modelfiles deleted - verified 23 Modelfiles remain (17 + 6)
  - 3 OBLITERATUS configs + the `27b-obliterated-coding` alias, and the `qwopus3.5/` family
  - The 35B q4 MTP pair and the non-MTP 35B entry
- [x] `35b-a3b-coding` alias repointed to the MTP-q5 coding config; rebuilt under Ollama
  - Verified 28 GB (q5 class; the old q4 build was 23 GB)
- [x] 9 Ollama models removed - verified `ollama list` = 23, matching the Modelfile count
- [x] HF cache: OBLITERATUS x2, noctrex, Jackrong Qwopus, non-MTP 35B repo, 35B q4 blob deleted - hub 285G -> 199G
  - 86G freed; q4/q5 blobs confirmed distinct before deletion
  - All 22 kept `FROM`/`DRAFT` paths resolve (19 + 3; count corrected from 20, re-verified 2026-07-28)

## Phase 0 - router protocol smokes

Completed 2026-07-28, all 11 smokes passed; evidence: `docs/history/2026-07-28-llamacpp-p0-smokes.md`.

- [x] `llamacpp/` skeleton: 3-model preset INI (incl. the guarded 9B non-MTP) + launcher on 11433
  - Verified: 19 keys map to b9860 flags, all paths resolve, `[*]` mechanics source-checked, copy sha256-identical
- [x] Launcher uses the absolute build/bin path and aborts unless `--version` reports 9860
  - Verified: assert substring matches live `--version` output; `bash -n` clean; abort branch untested (accepted)
  - Amended 2026-08-03 (user): abort removed after P1; launch.sh keeps the pin as a last-known-good record
  - The spec's rebuild rule moves that pin record forward (decision record in the P1 log)
- [x] Router up: `/v1/models` lists only preset entries (no `default` entry, no HF-cache auto-discovery)
  - One generation OK under the `LLAMA_CACHE` redirect
- [x] `/v1/messages` smoke via router: basic, streaming, tool loop, cache hits (427 cached tokens on turn 2)
  - Streaming block-overlap quirk at the thinking->text boundary logged for the P3 claude-local validation
- [x] Multi-system immunity check on `/v1/messages` (per-build) - two-block system 200
- [x] `/v1/chat/completions` + froggeric on a guarded Qwen - mid-conversation system 200, template byte-identical
- [x] `/v1/responses` Codex-shaped smoke with a function tool - round-trip completed, no 500
- [x] Per-child `/props` matches docs/parameters.md profile - all 3 children exact
  - `/props` `n_predict -1` is a pin display artifact; the request default is the flag value (server-schema.cpp:503)
- [x] Sleep-idle unload/reload observed (sleeping, VRAM released, ~3 s wake); models-max behavior recorded
  - Two 9B children coexist full-speed at 11.5/12.3 GiB, no eviction
- [x] Gemma thinking confirmed in a live response with no flags set; disable path and `-rea` mapping recorded
  - `enable_thinking:false` disables per-request; `-rea off` disables at launch
- [x] MTP x `--mmproj` behavior recorded - b9860 serves both from one entry, no conflict, loads fine unsplit
  - Image round-trip OK with drafting active, at a ~35-40% decode penalty; P2 splits for speed
- [x] Gemma drafter auto-discovery from a local snapshot path tested - none; explicit `model-draft` mandatory
  - Child dies without it: `failed to create MTP context`

## Phase 1 - stability envelopes

- [x] Gemma KV probe: llama-perplexity KL (f16 vs q8_0, one ~16k segment) + VRAM delta; type fixed before the ladder
  - Qwen was to be probed only if the Gemma result fell outside the decision rule
  - Decided 2026-08-03 (user): q8_0 fleet-wide - q8_0 KLD 0.072 == bf16's 0.070 vs the f16 base
  - The tail is dtype noise, and the Gemma result stayed inside the rule, so no Qwen probe ran
  - Evidence in `docs/history/2026-08-03-llamacpp-p1-envelopes.md`
- [x] Gemma 12B MTP ctx ladder (32k..200k, crash matrix per rung, graphs on); pick ceiling
  - 36/36 gens stable across all 6 rungs; ceiling 200000; the eval's 200k crash did not reproduce (n=6)
- [x] 26B MTP pair checked at the chosen ceiling
  - 6/6 gens stable at 131072 (its profile ctx), 39.1-41.7 tok/s, acceptance 0.62-0.74, `-ngl auto` partial offload
- [x] Qwen-MTP graphs-on hammer, 30 gens, 0 crashes (crash = contingency trigger)
  - 30/30 clean against the router child, full 4096 tokens each, 98-121 tok/s; contingency not triggered
- [x] Results written to a dated docs/history log
  - `docs/history/2026-08-03-llamacpp-p1-envelopes.md` + index row

## Phase 2 - full-fleet config home

- [x] Preset INI: 17 configs + 6 aliases, full flags, mmproj, drafters, froggeric on the 3 guarded-GGUF entries
  - Verified: 17 sections + 6 alias names, all 29 file paths resolve, `alias`/`reasoning` are b9860 flags
  - Review sweep 2026-08-03: `enable_thinking` via kwargs is deprecated on the pin -> `reasoning = off`
  - MTP x vision split applied: MTP entries carry no mmproj; policy recorded in docs/parameters.md
  - The 35B instruct canonical serves plain (no spec-type) with mmproj as that family's vision entry
- [x] Serving flags set (`-fa on`, KV type, `-np 1`, `--jinja`) and explicit `min_p` on every entry
  - Verified: `[*]` carries all four, plus the fleet-constant sampling keys hoisted at the review sweep
  - min-p/n-predict/repeat-penalty/top-p/presence-penalty live in `[*]`; per-entry values only where they differ
- [x] froggeric template pinned into `llamacpp/templates/`
  - Done at P0; sha256 `d203f334...` re-verified at P2
- [x] `llamacpp/README.md`: layout, alias policy, add-a-model procedure
- [x] Name-parity check against `ollama list`; spot-loads verified via `/props` (4 ran)
  - Parity EXACT 2026-08-03: 17 ids + 6 aliases == the 23 `ollama list` names
  - Heretic templates extracted offline 2026-08-03 (review-sweep M8): zero `raise_exception` in either GGUF
  - Spot-loads 2026-08-04: PASS 4/4 (31b-mtp, queen-27b-coding, 35b-a3b-mtp-coding, 26b-heretic carrying the probe)
  - Spot-load `/props`: sampling exact per profile on all 4; ctx-size pads to a 256 boundary (200000 -> 200192)
  - Spot-load `/props` display-only artifacts: `n_predict -1` (known P0), `speculative.types "none"` while drafting
  - Queen's served template byte-identical to froggeric; acceptance 0.83 (31B pair) / 0.88 (35B); no CUDA lines
  - Heretic probe HTTP 200 via the "outdated gemma4 chat template" compat rewrite (3 warnings; unsloth sibling 0)
  - That multi-system pass depends on the upstream compat workaround staying present
  - 31B `-ngl auto` fitting could not measure the drafter ("failed to measure draft model memory"); worked anyway
  - Finding 2026-08-04: the 31B MTP entry serves ctx 200000 but its drafter is trained at 131072
  - Source: drafter GGUF `gemma4-assistant.context_length = 131072`; load warns "possible training context overflow"
  - 12B's drafter is trained at 262144 (fine at 200000); the 26B pair serves exactly its drafter's 131072
  - Speculation is output-invariant: the exposure is acceptance/speed past ~131k positions, not correctness
  - Decided 2026-08-04 (user): keep 200000; noted on the models.ini entry

## Phase 3 - client cutovers

- [x] claude-local rewired: base URL 11433, tier vars, `--disallowedTools WebSearch`, web-search MCP
  - Applied 2026-08-04 (user consent), with one deviation from the plan
  - The `=` flag form is required: the space form consumes `"$@"` as the flag's value
  - MCP: per-invocation `--mcp-config` only, pipx runs the vendored script; pins + provenance: `llamacpp/mcp/README.md`
  - Negative-check: nothing registered globally (`~/.claude.json` had no mcpServers)
- [x] `OLLAMA_API_KEY` moved to a user-readable env file for the MCP
  - Copied (not moved) 2026-08-04: the spec freezes the systemd override until the Phase 4 purge; env file is mode 600
- [x] claude-local validated: tool loop, live MCP search, body-log check, cache hits, WebFetch
  - PASS 9/9 on the live router 2026-08-04; validation detail in the P3 log
  - Blocker fixed en route: `ANTHROPIC_MODEL` is now pinned
  - Without that pin, settings.json's literal model is sent to the router verbatim
  - WebSearch verified absent from the request bodies: `web_search_20250305` count 0 across all 21 body-log files
  - Side result (n=1, moot since the 2026-08-10 crash closure): MTP x graphs-on served 10 requests to 26.2k ctx
  - That run reused graphs to 1030, with zero crashes
- [x] Open WebUI on OpenAI connection 11433; fleet in picker; search-enabled chat passes
  - Prepped 2026-08-04 (0.11.0 first start over a backup)
  - Browser cutover, search chats, and family-chat DB verification done 2026-08-07; full detail in the P3 log
  - Those chats were cross-matched to the router log verbatim
  - Sampling neutrality closed at source (`payload.py:70`)
  - Connection research settled: external + chat-completions, Provider=llama.cpp recommended
  - Reason: reasoning round-trip + Loaded/Eject (sites: middleware.py:2059-2073 -> misc.py:437-439 at 0.11.0)
  - Guidance lives in docs/openwebui.md
  - Findings dispatched; the mechanism and evidence for each are in the P3 log
  - Finding: the 26B drafter NaN-split crash was root-caused, fixed by `spec-draft-ngl = 0` + `--models-max 1`
  - Both of those live in models.ini/launch.sh (user go)
  - Finding: the dense-offloader ~2-3 tok/s attribution was corrected - offload-bound, not residency
  - Finding: the 35B `/` repetition loop is sampling degeneracy; regenerating escapes it
  - Finding: `--models-max 1` force-kills an in-flight generation on switch after 10 s
- [x] OpenCode provider block + context limits; search-tool behavior recorded
  - Applied + validated 2026-08-04: 12-model provider, real tool-loop session, requests reach 11433
  - No #5674 symptom; no websearch tool exists in 1.16.2
  - Upstream client bug found: `opencode run` drops final stdout text, though stored text is intact via export
  - Seen in 4/4 sessions, TUI untested; detail in the P3 log
- [x] Codex custom provider (Responses, fresh threads); tool loop tested or upstream-blocked documented
  - Applied + validated 2026-08-04 (tool loop via exec_command; `/v1/responses` -> canonical child; #10635 dead)
  - Auth caveat: the validation ran with the ambient ChatGPT credential present; the P3 log carries this one
  - Auth caveat: authless-without-login and the env_key fallback stay unvalidated; the env_key clause survives here
  - Cleanup: the trust entry Codex self-wrote for the validation sandbox was removed; marketplace drift left as-is
  - Finding: llama-server silently skips `namespace`/`web_search` Responses tools at 200, so Codex MCP fails invisibly
  - That finding was folded into architecture.md at the Phase 4 docs rewrite; auth + phone-home caveats in the P3 log
  - #26977's zero hits mean the path was never exercised, not fixed - the risk on plan.md's Watch list stays open
- [x] Pi best-effort config tried or explicitly deferred
  - Explicitly deferred 2026-08-07 (user: "defer pi for now"); Pi is not installed here, so nothing was rewired
  - No Pi config landed in the repo; wire it from `llamacpp/models.ini` at pickup - does not block Phase 4

## Phase 4 - staged retirement

### Open items

- [ ] Validation window (~2 weeks daily use) completed without rollback
- [ ] Purge (user-confirmed): store deleted, modelfiles/ + create script retired, vhdx compacted
  - [ ] Same pass: demote the Ollama benchmark suites and the AGENTS.md Commands block
  - Both of those are unrunnable once the binary and store go
  - Pruned HF snapshots are already gone, deleted at the fleet reduction
- [ ] Disk numbers and final state recorded in a dated docs/history log
- [ ] At spec close: prune the spec.md Watch list to still-live issues (entries are as-recorded, not re-checked)

### Closed items

- [x] Prerequisites met (claude-local, Open WebUI, OpenCode validated; Codex validated or documented-blocked)
  - Met 2026-08-07: all four cutovers validated (claude-local/OpenCode/Codex 2026-08-04, Open WebUI 2026-08-07)
- [x] ollama.service stopped + disabled (user runs sudo)
  - Done 2026-08-07 (user ran sudo; stop and disable verified live: is-active inactive, is-enabled disabled)
  - Port 11434 closed; store/binaries/override stay frozen on disk until the purge
  - Validation window starts 2026-08-07; purge eligible ~2026-08-21 on explicit user go
- [x] Docs rewritten: architecture.md, AGENTS.md, README, CLAUDE.md note, benchmarking.md pending-action dropped
  - 2026-08-07: six files (those plus openwebui.md and parameters.md touch-ups); rumdl-clean then (MD013 carryovers persist)
  - architecture.md redrawn for the router: runbook, frozen-legacy framing, fresh du figures (HF 199G, store 186G)
  - The silent Responses tool-drop folded into architecture.md + openwebui.md; openwebui.md guidance inverted
  - benchmarking.md pending action replaced by the graphs-on stance with P1 evidence
  - launch.sh pin documented as record-not-assertion (reconciles the spec's pin-enforcement wording)
- [x] PR #15 review response (2026-08-08): merge-gating comments addressed
  - The dated sections below are that response and everything it pulled in, through 2026-08-11

### PR #15 review response - 2026-08-08

- Applied: README catalog tables deleted (root-cause de-drift); live counts corrected to 20 configs + 9 aliases
  - (Superseded: the counts moved through 17+8 to 18 configs + 8 aliases at the 2026-08-08 reshape)
- Spec-class lock lifted by user: spec.md/plan.md carry dated amendments (counts; pin-assert superseded note)
- q6 aliases reshaped per user: self-identical names dropped; reasoning gains qwen3.6-35b-a3b-reasoning-ud-q6-k
- launch.sh: --cors-origins localhost added (user picked B4a); overlay/bind comments; build record updated
  - Finding: POST /models executes regardless of CORS or --api-key at b10326 (path-only public-endpoint exemption)
  - Full closure = upstream fix or local patch; neither taken; upstream report not filed (not authorized)

### Build record moved to b10326 - 2026-08-08

- The on-disk build moved to b10326 (3653e6d6d, 2026-08-07)
- Its failed re-cert (Qwen hammer 2/30) plus the same-day ~88k-ctx live crash-loop opened the crash investigation
  - Consolidated in the crash-investigation CLOSED section below; per-stage evidence in diagnosis log sections 1-8
- Power caveat kept for b9860: its 30/30 hammer had ~11% pass-by-luck odds at a true 7%/run
  - The blamed design predates b9860, so that clean run never certified the build
- Post-mortem audit 2026-08-08 (1 opus + 2 sonnet, adversarial) of the "weeks of crash-free mileage" claim
  - Provenance traced: spec future-tense read as past evidence, and cross-model conflation
  - 14-commit sweep: 15 confirmed / 2 overstated / 4 refuted / 3 unverifiable; fixes applied at head
- Direction-of-error note kept: every soft spot leaned toward making b9860 look cleaner than its record

### Final sweep response - 2026-08-09 (head 9bdd96e)

6 must-fix + 8 should-fix + nit triage dispatched.

- Decided (user): MCP range pins KEPT - re-resolution risk accepted and documented; == pins declined
- Decided (user): launch.sh gains port preflight, --version log echo, env -u OLLAMA_API_KEY, cache-dir warn
- Decided (user): .claude/settings.json deleted (dead config)
- Decided: the comment in the frozen 35b-a3b-coding Modelfile is declined (freeze policy outranks the nit)
- models.ini polish nits (per-entry ctx comments, :89 header length, alias asymmetry) skipped as polish
- Decided 2026-08-08 (user): downgrading is NOT an option - the current on-disk build is canonical, always
  - Mitigation must be config-side or upstream-forward; the last-known-good record stays a record only

### claude-local lane selection (B6) - 2026-08-08

Decided 2026-08-08 (user): the B6 deferral is revoked - "the wrapper change MUST be taken"; fix applied same day.

- First fix: claude-local consumes a --model flag, so main + tier + subagent vars follow one _cl_model knob
  - Stub-verified: default, --model X, --model=X, and missing-value abort; flag never reaches claude itself
  - Discovery en route: the wrapper had been repointed to gemma4-12b-it-qat-mtp for ALL roles (docs said 35B)
  - Default stays gemma4-12b-it-qat-mtp (owner's standing pin) pending the 35B large-ctx verdict; docs updated
- Amended same day (user, iterated): NO flag and NO default - selection is a numbered menu, Enter = last lane
  - The last lane persists in ~/.config/claude-local.last; non-TTY reuses it or fails with the fleet list
  - claude's own --model is not overloaded; every claude arg passes through untouched
  - Re-verified via stub + pty: menu pick, Enter-reuse, non-TTY reuse note, out-of-range abort, passthrough
- Simplify review (opus) applied 2026-08-08 to that menu: decimal 10# index (fixes octal 08/09), empty-ini guard
  - Off-list picks launch visibly but are not persisted; EOF aborts; the verbatim-name fallback is documented in fn + CLAUDE.md
  - Menu ordering resolved 2026-08-09 (user, "why not just a simple sort"): LC_ALL=C sort over ids + aliases
  - That sort is the simplest of the three options (no file-order dependency)
  - It also lists each alias next to its canonical id for free
  - Reviewer note: stub/pty-verified only so far; one real interactive + one non-TTY run still owed live

### Quant designations removed from served ids - 2026-08-09

Decided 2026-08-09 (user, "remove quant designations from names"): served ids name the entry, never the quant.

- 12 of 18 ids renamed; the 6 Gemma QAT ids keep `qat` (training method, not a quant designation - user ruled)
- Alias layer collapses 8 -> 1: five equalled their own entry's new id (silent-drop collision), two were quant-named
- Survivor `qwen3.6-35b-a3b-coding` -> the MTP coding lane; it sits in tension with the mtp-explicit rule (open)
- Fleet is 18 configs + 1 alias name; verified live (18 ids served, zero quant suffixes, alias resolving)
- Reverses the 2026-08-08 Queen `-i1` tag-fidelity rename and retires the AGENTS.md verbatim-quant-tag rule
- Swept: models.ini, OpenCode, Codex catalog + default, AGENTS.md, llamacpp/README.md, docs, pending specs
- Frozen harnesses left as-is (the benchmark `matrix.tsv` files hold retired Ollama names; Modelfiles stay frozen)
- Open WebUI: 3 live names in stored chats break on resume (the DB already held 5 dead names pre-rename)

### GPU batch 2 on the renamed fleet - 2026-08-09

- Results and the GGML_CUDA_DISABLE_GRAPHS retraction are in the 2026-08-08 history log (section 5)
- The graphs-env facts live in AGENTS.md (Serving) + docs/benchmarking.md
- 31B drafter load: PASS without the 26B's spec-draft-ngl pin (n=1; pin question stays open on evidence)
- Instruct-entry chat-template gate probes post-rename: qwen3.6-27b and qwen3.6-35b-a3b both 200, no guard error

### Upstream research, isolation batch, and the b10335 build move - 2026-08-09

All findings here are superseded by the crash-investigation CLOSED section below.
Stage evidence is in the diagnosis log + dossier log.

- MTP isolated as the trigger axis (p = 0.002 pooled)
- NOT a regression: b9860 recorded the same crash class at 200k, so reverting is unsupported
- Rebuild to b10335 changed nothing (5/5, p = 1.0)
- No upstream fix existed (#26609/#26558/#26782 all mismatched or open)
- llama.cpp bans AI-written reports (CONTRIBUTING.md): any filing is owner-written; agents supply raw material
- Second upstream bug found en route (still reportable): POST /models/unload racing a crashed instance
  - It orphans the name in stopping_models, force-killing the next same-name instance at 10 s (server-models.cpp:1085)
- Caveat kept: `"cache_prompt": false` is silently ignored on /v1/messages; force freshness via POST /models/unload
- Per-build /v1/messages multi-system immunity probe on b10335: PASS

### Fleet reshape package - 2026-08-08

Decided 2026-08-08 (user): the reshape below, blocked on the new-GGUF chat-template gate + the build fix.

- 35B instruct: repoint to unsloth/Qwen3.6-35B-A3B-GGUF (UD-Q6_K + mmproj); rename qwen3.6-35b-a3b-ud-q6-k
  - No compat alias (old-name requests fail visibly); OpenCode/Codex ids swap in the same batch
- Naming axes: profile token (blank = instruct); -mtp- explicit on every MTP-serving name
  - Vision is the plain entry's mmproj property, not a name token; blank entries are not defaults (no bare alias)
- qwen3.6-27b gains a blank instruct entry qwen3.6-27b-ud-q4-k-xl (Instruct profile, non-MTP GGUF + mmproj, q4)
  - Fleet becomes 18 configs + 8 alias names at the reshape (ctx mirrors the plain 27B entry, 131072)
- Queen-27B ids gain quant-tag fidelity -i1-q4-k-m (upstream i1-Q4_K_M, Heretic precedent); no compat alias
- No alias moves at 27B: qwen3.6-27b-coding stays on the plain coding entry (mtp-explicit rule)
- Executed 2026-08-08 config-side only - the GPU work window was closed that day
  - models.ini 18 + 8, OpenCode/Codex swapped, doc counts moved
  - Download complete (29.3G blob, snapshot a483e9e6); stale 16.9G .incomplete removed
  - New-GGUF gate greps: guard 0, merged_system 7 - joins the carriers (now 5 GGUFs / 7 entries)

### GPU-window diagnosis queue - 2026-08-08

- Every queued stage has since completed, across the 2026-08-09 batch and the 2026-08-10 resolution
  - The 35B large-ctx result is bound on n=1
  - Amended 2026-08-10: the earlier "stages still owed" note was stale
- The per-build /v1/messages probe stays standing whenever the build moves; evidence in the diagnosis log

### merged_system exposure accepted - 2026-08-08

Decided 2026-08-08 (user): the merged_system exposure is accepted and documented (5 GGUFs / 7 entries post-reshape).

- Those entries would silently drop mid-conversation system messages on /v1/chat/completions (no error surfaces)
- No live exposure: the one multi-system client uses `/v1/messages`; OpenAI-endpoint clients send leading-only
- The gate's merged_system step flags future carriers at vetting; froggeric extension rejected as overengineering

### Review items B6a and B8 - 2026-08-08

- claude-local subagent pinning documented in CLAUDE.md (B6a); wrapper change not taken
- Decided (user): OTEL body-log cleanup (B8) stays held - the owner has not released it

### froggeric template whitespace patch - 2026-08-08

Fixed 2026-08-08 (user "1"): the 9-tag whitespace patch is applied to the vendored template; render verified.

- Provenance + new sha recorded in templates/README.md; upstream report (option 2) not taken
- Chat-template gate re-validation of the patched (template, b10335) pair: PASS 2026-08-10
  - Multi-system /v1/chat/completions returned 200 on all 3 guarded entries; template sha 8daaa08a re-verified
  - Control (9B, no override, -ngl 0): guard fired, so the override is load-bearing; sanity single-system = 200
  - Finding: the guard returns HTTP 500 on b10335, not 400 as at b10326
  - AGENTS.md gate step 3 therefore matches on the guard message text, never the status code
  - A code-only check would read that 500 as "not guarded" and pass a guarded GGUF
- Online investigation 2026-08-08 (all 66 repo discussions grepped byte-exact): the bug is unreported - novel
- It is a v21.3 regression: the vulnerable split landed in the repo's last commit (2026-07-02); v21.2 was immune
- Qwen/unsloth official templates are immune by construction (single string literal); froggeric-only exposure
- Undiagnosed symptom threads #55/#56/#64 (broken tool calls "with v21.3") are consistent with this root cause
- Author pattern: bursty batch fixes, 5-week lull ongoing; best traction = detailed repro report (#43 precedent)

### Validation window clock - 2026-08-08

Decided 2026-08-08 (user): the #32 window clock does NOT restart at the b10326 re-cert; the 2026-08-07 opening stands.

### Q6 is the 35B standard - 2026-08-08

Decided 2026-08-08 (user, "Q6 quants for 35B are now standard. no more others").

- Unsuffixed 35B aliases repointed q5 -> q6 in models.ini; claude-local follows automatically via its alias
- Decided 2026-08-08 (user): the 35B q5 trio deleted from models.ini - fleet is 17 configs + 9 alias names
  - (The 9 was the arithmetic slip - 8 actual; superseded by the reshape -> 18 configs + 8 aliases)
- OpenCode + Codex swapped to the q6 ids (catalog, provider list, and the Codex coding default)
  - ctx limits carry over unchanged (coding 200000; reasoning/instruct 262144)
- Deleted 2026-08-08 (user go): the 35B UD-Q5_K_XL GGUF blob (26G measured) removed from the HF cache
  - Guest / usage 484G -> 459G; q6 + mmproj blobs untouched; host vhdx reclaim folds into the purge step
  - The frozen q5 canonical Modelfile keeps its dead FROM path (build-time only; store copy serves rollback)

### Crash investigation CLOSED - 2026-08-10

The cause was this box's +230 MHz GPU core clock offset, nothing upstream.

- Arc: Id-13 fault clusters pointed local (diagnosis log section 9)
  - Stock clocks cleared the byte-identical repro (section 10)
  - The 4-arm decomposition isolated the core offset alone (section 11)
- Mechanism: voltage-for-frequency below the validated band
  - The OC was validated under full load (~1100 mV) and LLM decode runs lower
  - Peak clock reads identically in crashing and clean arms
- Ladder CLOSED: +120 MHz adopted as the safe core offset
  - Standing rule + per-rung stats in AGENTS.md and docs/benchmarking.md
- Caveat kept: the core offset is NOT verifiable from WSL (the clamp hides it)
  - The rule rests on the owner's Afterburner profile
  - The Id-13 delta is one-directional: nonzero = hardware fault, zero proves nothing
- gemma4-12b-it-qat-mtp DECISION VOID: the entry was never broken and is kept unchanged
- Dossier CLOSED, nothing filed; the b10335 crash matrix PASSES
- The froggeric (template, b10335) pair passed 2026-08-10 (templates/README.md)
- Full record: diagnosis log sections 9-12
- Follow-on: specs/gpu-stability-test packages the crash matrix as one certifying command

### Review-sweep judgment calls - 2026-08-10

Decided 2026-08-10 (user, "1. exit, 2. remove, 3. single-home, 4. collapse all three").

- launch.sh exits on a non-empty LLAMA_CACHE
- SLEEP_IDLE_SECONDS/MODELS_MAX env knobs removed, since the last flag value given takes effect
- Build record single-homed in launch.sh, crash status in docs/benchmarking.md; the satellites became pointers
- Also collapsed: MTP mechanisms -> architecture.md s3, FA+q8_0 -> AGENTS.md, guarded count -> templates/README.md

### Final sweep response - 2026-08-10 (head 05f08c5 + repo-independence addendum)

All 34 in-repo findings applied after per-site verification (user: "everything in-repo").
The tasks.md collapse was scoped to closed sections (user).

- Must-fix: launch.sh build record -> re-certified 2026-08-10
- Must-fix: "guard = 400" corrected at 4 live sites (vet on the guard message text)
- Must-fix: OpenCode/Codex id counts 12 -> 13
- Must-fix: the Id-13 rule rewritten one-directional (+ gpu-stability spec)
- Structural: crash section retitled + anchors swept; id grammar single-homed in llamacpp/README.md
- Structural: fleet-count copies deduped; AGENTS.md MD013 hits split
- Structural: .gitignore +.claude settings, -.cache-empty (strays now visible)
- Structural: CSRF impact restated (fleet-join, launch-wedge, vhdx growth); the env -u scrub commented at its site
- Machine side (user go): the claude-local menu now polls GET /v1/models, repo-independent per the owner decision
  - Aliases stay listed via each entry's aliases field (source-verified at server-models.cpp get_router_models)
  - The 00-selects-last-lane bug was fixed in the same pass
  - B8 exposure documented in the claude-local spec; MCP transitive-dep acceptance extended in mcp/README.md
- Superseded same day by the cross-machine unification (~/.claude handoff doc, Windows session)
  - The logic moved to the synced ~/.claude/bin/claude-local; the ~/.bashrc fn became a one-line shim over it
  - Ported into the synced script: the 00 fix, the alias merge (its port read ids only), and a status-column fix
  - That status fix: /v1/models status is an object, so the port would have printed the dict - .value extracted
  - New behavior gained: per-session plugin disable (--settings built from settings.json)
  - MCP wiring now requires ~/.config/claude-local.mcp.json to exist (WSL-only)
  - Spec home moved same day (user rule: this repo owns everything locally-run, Claude included)
  - The canonical spec is AGENTS.md#claude-local; CLAUDE.md is a thin pointer again
  - All pointers swept: synced-script header, bashrc shim, architecture.md client block
- Wrapper verification: the actual synced script tested under a scratch HOME + pty with stubbed curl/claude - all PASS
  - Covered: menu render (ids + alias + status), index/Enter/verbatim/00/out-of-range picks
  - Covered: non-TTY reuse and no-last failure, router-down message, MCP branch flags, env-file fail-closed
  - One real interactive + one non-TTY live run against the live router still owed (carried forward)
  - The 2026-08-11 script rewrite was re-verified meanwhile via an 11-check stub matrix (final sweep, PR #15)

### Post-commit sweep on f1b8696 - 2026-08-11

4 opus lenses + an inline permission-scope null. All 35 prior items verified resolved with zero regressions.
The new findings were dispatched on user go (all four tiers approved).

- REVERSED item 29: the .cache-empty ignore is restored
  - Un-ignoring made bare-hex blob downloads commit-eligible while *.gguf still hid the symlinks
  - launch.sh's fail-closed guard is the real control; .claude/worktrees/ joined the tracked ignores
- Fixed in round-1 text: the 766/780 qualifier (four-day window, not the located subset)
- Fixed in round-1 text: the env -u rationale split (HF_TOKEN caps downloads; OLLAMA_API_KEY is unread by llama-server)
- The spec now scopes env-file sourcing to the MCP branch and names the dummy auth token
- The spec marks B8 firing UNVERIFIED, since whether it logs anything depends on the telemetry settings
- Collapse orphans restored inline above (P3 log:6-7 names this file the surviving record for 2026-08-04)
- Synced script hardened (user: all three): plugin kill-switch fails closed, python parse aborts visibly
  - Unprintable router ids skipped with a warning
  - OLLAMA_API_KEY inheritance accepted + documented (mcp/README.md)
- Dedup applied (user: pointers win over round-1's models.ini restatements); CLAUDE.md cut to a pure pointer

### Simplify round - 2026-08-11

2 opus lenses (user: "go ahead on all").

- The synced claude-local script rewritten, 110 -> ~100 lines
  - Real bug fixed: the empty-fleet guard never fired
  - Dead fallbacks replaced by fail-visibly indexing; the control-char filter dropped as guarding no trust boundary
  - Plugin build hoisted above the menu; alias rows show status
- AGENTS.md restyled to the instruction register: ~240 -> ~130 lines, 15 -> 9 sections
  - All dated/evidence lines routed to verified homes (Firefox/Karpathy/Cherny references, user-directed)
- Legacy narrative + archaeology trimmed across README, architecture, benchmarking, parameters, openwebui
  - DiffusionGemma cut from parameters
- 5 must-move orphan candidates relocated first
  - merged_system inventory -> llamacpp/README.md; graphs-reused note -> benchmarking.md
  - Modelfile scheme -> architecture.md s2; ollama-create.sh usage header; LLAMA_ARG_* citation
