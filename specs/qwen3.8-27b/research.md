# Qwen3.8 series research findings (2026-08-16)

RECORD - written 2026-08-16 and kept as written; re-verify its claims at pickup.

Research record for this spec bundle. Sources: a 4-agent research workflow (2 haiku web sweeps, 2 sonnet source
deep-reads, run `wf_2f315fcc-a63`), plus same-session first-hand checks: the official model card fetch, the official
`chat_template.jinja` fetch, and the on-box build probe. Web claims are single-source quotes unless marked verified;
nothing here is benchmarked on this box.

## Series

Announced 2026-07-19 ([latent.space](https://www.latent.space/p/ainews-qwen-38-max24t-and-27b-new): "Qwen3.8 was
announced on July 19, 2026 by Qwen, the AI team at China's Alibaba"); open weights shipped mid-August 2026.
Exact per-model release dates conflict across sources (Aug 5 / Aug 12 / Aug 14-15) - UNVERIFIED, immaterial to adoption.

| Model | Params | Arch | Ctx | Vision | Thinking | License |
|---|---|---|---|---|---|---|
| [Qwen3.8-27B](https://huggingface.co/Qwen/Qwen3.8-27B) | 27B dense | 64 layers: 16 x (3 x (Gated DeltaNet -> FFN) -> 1 x (Gated Attention -> FFN)) | 262,144 native, extensible to 1M via static YaRN | image + video | on by default, per-request disable, `reasoning_effort` | Apache 2.0 |
| [Qwen3.8-2.4T-A95B](https://huggingface.co/Qwen/Qwen3.8-2.4T-A95B) | 2.4T MoE, 95B active | 92 layers, 512 experts (10 routed + 1 shared) | 262,144 native, extensible to 1,010,000 | text-only | mandatory ("thinking cannot be disabled") | Qwen3.8-Max License, proprietary; restriction text UNVERIFIED beyond the name |
| Qwen3.8-Max | API product | - | ~1M | multimodal | - | closed |

- **This supersedes the bonsai record's base-model-churn caveat** (`specs/bonsai-27b/research.md`: "Qwen3.7 is
  API-only and closed, with no open-weight successor to Qwen3.6-27B"): Qwen3.8-27B is that successor, Apache 2.0.
- Only the 27B is in this box's class; the 2.4T-A95B (95B active) is out of scope for a 12 GB card, full stop.
- No coder-specific variant surfaced in either sweep - absence UNVERIFIED (two web sweeps, not an exhaustive census).

## Qwen3.8-27B - card facts (verified first-hand, card fetch 2026-08-16)

- License "apache-2.0"; "Number of Parameters: 27B"; dense.
- "Context Length: 262,144 natively and extensible up to 1,000,000 tokens." YaRN is static - the card advises
  enabling it only when actually processing long context, since it "potentially impact[s] performance on shorter texts".
- Vision: "Native support for image and video understanding, from STEM diagrams and documents to hour-scale videos."
- "MTP (Multi-Token Prediction): trained with multiple steps" - MTP is embedded, not a separate drafter repo (below).
- Same 64-layer hybrid shape as Qwen3.6-27B (16 of 64 layers full attention) - KV sizing behaves like the served
  3.6 entries: growing KV only on the Gated Attention layers (cf. `specs/bonsai-27b/research.md`, hybrid-SSM section).
- Agentic output budgets: the card recommends "Reasoning Content: ... 262,144 tokens" / "Final Response: ... 131,072
  tokens" maximum output lengths; the fleet's `n-predict` is 65536 fleet-wide - revisit at spec review.

## Runtime support - the gates

- llama.cpp arch is `qwen35` / `qwen35moe`, added text-only by
  [PR #19435](https://github.com/ggml-org/llama.cpp/pull/19435) "[Model] Qwen3.5 dense and MoE support (no vision)":
  "For now, only add text support, without the multimodal capabilities."
  One fetch claimed the PR was "subsequently reverted" - UNVERIFIED, re-check PR/commit status at pickup.
- **Build gate: the on-box llama-server is b10335 (`74ce15741`, probed 2026-08-16); the CUDA Gated-DeltaNet fix
  lands later.** [Discussion #27164](https://github.com/ggml-org/llama.cpp/discussions/27164): garbage output
  ("corrupted text output from Qwen3.8-27B in llama.cpp with CUDA on WSL/RTX 3090" - same WSL2/CUDA class as this
  box); fix is "Update from commit 221f0f6 to approximately ece963f41 (build 10450)", updating the shared CUDA
  libraries too, not just the binary. **Do not serve 3.8 on b10335; rebuild first.**
  - Synergy: `specs/stack-upkeep` already holds a rebuild reason ("A Qwen tool-calling fix is waiting in an unbuilt
    llama.cpp"); one rebuild covers both, then the (template, build) validation reruns per `llamacpp/templates/README.md`.
- Vision on this arch family is doubtful today: excluded from #19435; mmproj CLIP crash on the family
  ([#21268](https://github.com/ggml-org/llama.cpp/issues/21268), Qwen3.5-122B, "CLIP graph uses unsupported
  operators by the backend"). Probe mmproj on-box before giving 3.8 the vision slot; until then 3.6 keeps it.
- Tool calling: same-family precedent [#21158](https://github.com/ggml-org/llama.cpp/issues/21158) "Qwen3.5-27B tool
  call parsing still broken after PR #20424"; no 3.8-specific report found. Every coding lane sends tools - probe it.
- MoE-sibling CUDA degenerate-output issue [#19683](https://github.com/ggml-org/llama.cpp/issues/19683) (`qwen35moe`,
  all-"/" tokens) - family context only; the 27B is dense.

## GGUF availability

| Repo | Covers | Q4-Q6 files (GB) | mmproj | MTP |
|---|---|---|---|---|
| [unsloth/Qwen3.8-27B-GGUF](https://huggingface.co/unsloth/Qwen3.8-27B-GGUF) | base 27B | UD-IQ4_XS 15.7; Q4_K_S 16.1; Q4_K_M 17.1; **UD-Q4_K_XL 17.9**; Q5_K_S 19.3; Q5_K_M 19.8; UD-Q5_K_XL 20.2; Q6_K 22.9; UD-Q6_K_XL 25.9 | not seen in the fetched listing - check the file tree | embedded in the main GGUF ("It's already there", [discussion #12](https://huggingface.co/unsloth/Qwen3.8-27B-GGUF/discussions/12)); no separate -MTP repo, unlike 3.5/3.6 |
| [bartowski/Qwen3.8-27B-GGUF](https://huggingface.co/bartowski/Qwen3.8-27B-GGUF) | base 27B | Q4_K_S 16.71 ... Q6_K_L 24.08; Q8_0 29.12 | yes: `mmproj-Qwen3.8-27B-f16.gguf` / `-bf16.gguf`, "pair with any quant" | none listed |
| [mradermacher/Qwen3.8-27B-heretic-ara-GGUF](https://huggingface.co/mradermacher/Qwen3.8-27B-heretic-ara-GGUF) | heretic-ara finetune only, not the base model | Q2_K 10.9 -> Q8_0 29 (static + i1) | unconfirmed | none found |
| [ggml-org/Qwen3.8-27B-GGUF](https://huggingface.co/ggml-org/Qwen3.8-27B-GGUF) | base 27B, auto-converted | fetch returned garbled sizes - UNVERIFIED | unconfirmed | possible bundled MTP-only files, figures inconsistent - re-verify on the file tree |

- Fleet-convention pick: **unsloth `Qwen3.8-27B-UD-Q4_K_XL.gguf`, 17.9 GB** - the same quant tier and size class as
  the served Qwen3.6-27B entry, so it partial-offloads the same way on the 12 GB card.
- MTP caveat from the same unsloth thread: "Low quants with MTP make the model slower, not faster" (one user, low-VRAM
  context); a third-party MTP-only draft exists
  ([a4lg/Qwen3.8-27B-MTP-ONLY-GGUF](https://huggingface.co/a4lg/Qwen3.8-27B-MTP-ONLY-GGUF)). How llama-server engages
  embedded MTP here (auto vs `spec-type = draft-mtp` vs external `model-draft`) is unresolved - settle on-box, A/B it.

## Chat template - gate result (verified first-hand, raw fetch 2026-08-16)

- The official `chat_template.jinja` **carries the guard verbatim**:
  `raise_exception('System message must be at the beginning.')`; no `merged_system` anywhere.
  The standing family rule (`specs/done/chat-template-refresh`) extends to 3.8 unchanged: OpenAI-endpoint entries
  serve a guard-free replacement template.
- The template adds a `reasoning_effort` guard: "Supported types are xhigh (default), medium, and low."
  Whether llama-server passes `reasoning_effort` through is unknown - probe.
- froggeric v22 claims 3.8 support: "Version 22 includes support for Qwen 3.8 with reasoning effort steering"
  ([froggeric/Qwen-Fixed-Chat-Templates](https://huggingface.co/froggeric/Qwen-Fixed-Chat-Templates)). The vendored
  copy is v21.3 + the local whitespace fix - adoption means re-vendor v22, re-check the local fix against it, and
  validate the new (template, build) pair; the build moves anyway (build gate), so one validation pass covers both.
- unsloth claims its UD files ship "the corrected chat template"
  ([discussion #7](https://huggingface.co/unsloth/Qwen3.8-27B-GGUF/discussions/7)) - trust nothing embedded: run the
  AGENTS.md gate greps and the live probe on whichever GGUF gets pinned.

## Sampling

Card values, verified first-hand and identical between both open-weight cards; no self-inconsistency found this pass
(unlike 3.6's presence_penalty 0.0-vs-1.5 split across cards):

| Mode | Card values |
|---|---|
| thinking | temperature=1.0, top_p=0.95, top_k=20, min_p=0.0, presence_penalty=0.0, repetition_penalty=1.0 |
| non-thinking / instruct | temperature=0.7, top_p=0.80, top_k=20, min_p=0.0, presence_penalty=1.5, repetition_penalty=1.0 |

- These match the served "Qwen 3.6 (General Tasks, thinking)" and "(Instruct Mode)" profiles in `docs/parameters.md`
  value-for-value - existing profile blocks carry over unedited.
- `repetition_penalty=1.0` in both modes - consistent with the repeat_penalty-1.0 mandate; nothing to relitigate.
- No coding profile is published for 3.8 (card and unsloth docs give the two modes above only); the fleet's coding
  profile (temp 0.6) is the unsloth Qwen 3.6 convention - decide whether it carries over at spec review.
- Card caveat kept verbatim: "Adjust presence_penalty between 0-2" but a higher value "may occasionally result in
  language mixing and a slight decrease in model performance."

## Fleet fit

- Direct successor to the base model behind the qwen3.6-27b entries (coding, mtp-coding, mtp-reasoning, instruct) and
  the Bonsai rebuilds. Natural adoption shape: `qwen3.8-27b-{coding,reasoning,}` mirroring the 3.6 triple, ctx
  conventions unchanged (coding 200000; reasoning/instruct 262144 = the model's native ceiling; no YaRN).
- Vision entry only if the mmproj probe passes (runtime gate above); otherwise `qwen3.6-27b` keeps vision.
- Touches in-flight bundles: `specs/bonsai-27b` Phase 2 baselines against qwen3.6-27b-coding (still its base model -
  unaffected as a comparison, but the fleet's default 27B lane may move); `specs/kv-cache-ab` would gain a 3.8 arm if
  adopted; `specs/stack-upkeep` owns the rebuild this depends on.

## Open items this research could not settle

- The rebuild: confirm the DeltaNet fix commit/build at the source, rebuild past it, recertify per launch.sh practice.
- PR #19435 revert claim (UNVERIFIED) - check the PR and commit history directly.
- mmproj/vision on this arch on-box; unsloth mmproj presence in its file tree.
- Embedded-MTP engagement mechanism in llama-server, and whether MTP helps or hurts at Q4 on 12 GB - A/B.
- Tool-call parsing on 3.8 under llama-server (family precedent #21158).
- froggeric v22 re-vendor + (template, build) validation; gate greps + live probe on the pinned GGUF.
- Real throughput/VRAM on this box - nothing here is benched.

## Sources

[Qwen3.8-27B card](https://huggingface.co/Qwen/Qwen3.8-27B) -
[Qwen3.8-2.4T-A95B card](https://huggingface.co/Qwen/Qwen3.8-2.4T-A95B) -
[official chat_template.jinja](https://huggingface.co/Qwen/Qwen3.8-27B/raw/main/chat_template.jinja) -
[the-decoder release coverage](https://the-decoder.com/alibabas-qwen-team-releases-qwen-3-8-models-with-open-weights-under-the-apache-2-0-license/) -
[latent.space timeline](https://www.latent.space/p/ainews-qwen-38-max24t-and-27b-new) -
[unsloth GGUF repo](https://huggingface.co/unsloth/Qwen3.8-27B-GGUF) -
[unsloth 3.8 docs](https://unsloth.ai/docs/models/qwen3.8) -
[bartowski GGUF repo](https://huggingface.co/bartowski/Qwen3.8-27B-GGUF) -
[ggml-org GGUF repo](https://huggingface.co/ggml-org/Qwen3.8-27B-GGUF) -
[froggeric templates](https://huggingface.co/froggeric/Qwen-Fixed-Chat-Templates) -
[llama.cpp PR #19435](https://github.com/ggml-org/llama.cpp/pull/19435) -
[discussion #27164](https://github.com/ggml-org/llama.cpp/discussions/27164) -
[issue #21268](https://github.com/ggml-org/llama.cpp/issues/21268) -
[issue #21158](https://github.com/ggml-org/llama.cpp/issues/21158) -
[issue #19683](https://github.com/ggml-org/llama.cpp/issues/19683)
