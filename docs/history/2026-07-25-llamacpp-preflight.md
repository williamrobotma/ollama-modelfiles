# 2026-07-25: llamacpp-migration pre-flight check

Pre-flight pass over `specs/llamacpp-migration` before Phase 0 executes. No GPU loads, no serving changes.
Method: on-box binary and build-config inspection, b9860 source reads at the cited `file:line`, a full chat-template
extraction from a fleet GGUF, and vendor-doc fetches (Google, unsloth, Qwen model cards including raw READMEs).

Findings are grouped by what they change. Every claim carries its source; unverified items are marked as probes.

## Binary hygiene (fixed this session)

- Two `llama-server` binaries existed: repo-root `~/Developer/llama.cpp/llama-server` reporting `version: 9552
  (8a963fc10)` (Jun 7), and `build/bin/llama-server` reporting `version: 9860 (fdb1db877)` (Jul 3) - the spec's pin.
- The root set (`llama-cli`, `llama-gguf-split`, `llama-mtmd-cli`, `llama-server`) was an older build convention's
  output, untracked and ignored via `.gitignore:50` (`/llama-*`). Nothing in the repo referenced it;
  `benchmarks/llamacpp-parity/run.sh:13` already defaults to `$HOME/Developer/llama.cpp/build/bin/llama-server`.
- Neither binary is on `PATH`, so any launcher must carry an absolute path regardless.
- Risk if left: router children spawn from the router's own executable, resolved at runtime from `/proc/self/exe`
  (`tools/server/server-models.cpp:102`, assigned at `:258-265`). Launching the wrong binary silently runs the whole
  fleet on b9552, defeating the pin without any warning.
- Action taken: the four Jun 7 root binaries were deleted. The launcher gets the absolute `build/bin` path plus a
  `--version` assert on `9860`, so the pin enforces itself rather than living only in a doc.
- Build config is correct for the mandate: `GGML_CUDA:BOOL=ON`, `CMAKE_BUILD_TYPE:STRING=Release`, and
  `CMAKE_CUDA_COMPILER:FILEPATH=/home/wma/miniforge3/envs/llamacpp/bin/nvcc` reporting `release 13.3, V13.3.33`
  (`docs/parameters.md` mandate: CUDA 13.2 corrupts Gemma 4 output, use 13.1 or 13.3).

## Router mechanics (source-verified on the pin)

- Preset INI sections are `[name]`; keys are either `LLAMA_ARG_*` env names or CLI flag names with leading dashes
  stripped (`common/preset.cpp:255-258`). So arbitrary launch flags are expressible per model.
- `*` and `default` are special section names (`common/preset.cpp:291-292`), giving a global section for fleet-wide
  flags.
- `common_preset::to_args()` throws on an option carrying two values - "not supported yet" (`common/preset.cpp:72`).
- The router strips reserved args from child presets (SSL, API key, `models-*`) at
  `tools/server/server-models.cpp:143-155`; per-model `LLAMA_ARG_MODEL` / `MMPROJ` / `ALIAS` survive.
- Aliases work as planned: `-a, --alias STRING` is documented "set model name aliases, comma-separated (to be used by
  API)" and parsed from the preset at `tools/server/server-models.cpp:285`. The 7 alias names need no separate
  sections.
- **Children inherit the router's environment verbatim**: `std::vector<std::string> child_env = base_env; // copy`
  (`tools/server/server-models.cpp:892`), with only `LLAMA_SERVER_ROUTER_PORT` appended. There is no per-model env in
  the preset format.
  - Consequence: `GGML_CUDA_DISABLE_GRAPHS` is router-global. `docs/history/2026-07-17-llamacpp-eval.md:102` records
    per-model graphs control as the stock-side advantage over Ollama ("impossible on Ollama, issue #12083"); under
    router mode that advantage does not exist.
  - This is why a Phase-1 Qwen-MTP graphs-on hammer failure is a hard contingency trigger, not a tuning problem: the
    escape hatch is a standalone process on its own port, outside the router.

## Thinking activation: three sources reconciled

`docs/parameters.md` recorded "Gemma 4 thinking activates only with `<|think|>` at the start of the system prompt.
There is no other trigger." That is true of the Ollama path and wrong as a general statement.

- Google: "pass `enable_thinking=True`, the processor will insert the correct thinking tokens into the prompt". The
  `<|think|>` token insertion is automatic, not manual.
- unsloth's Gemma 4 page documents the manual form ("Add the token `<|think|>` at the start of the system prompt") and
  the disable form (`--chat-template-kwargs '{"enable_thinking":false}'`).
- The fleet GGUF's own template settles it. Extracted from
  `gemma-4-12B-it-qat-UD-Q4_K_XL.gguf` (18930 chars, embedded `tokenizer.chat_template`):

  ```jinja
  {%- set enable_thinking = enable_thinking | default(false) -%}
  ...
  {%- if enable_thinking or tools or (messages and messages[0]['role'] in ['system', 'developer']) -%}
      {{- '<|turn>system\n' -}}
      {#- Inject Thinking token at the very top of the FIRST system turn -#}
      {%- if enable_thinking -%}
          {{- '<|think|>\n' -}}
  ```

  and at the generation prompt, the false branch pre-closes the channel: `{%- if not enable_thinking -%}{{-
  '<|channel>thought\n<channel|>' -}}`.
- llama.cpp defaults the kwarg to true - `bool enable_thinking = true` at `common/chat.h:261` and
  `tools/server/server-common.h:296` - and passes it into the template at `common/chat.cpp:895`. A per-request
  `chat_template_kwargs` override is parsed at `tools/server/server-common.cpp:1078-1085`.
- Net for the migration: under `llama-server --jinja`, Gemma thinking is **on by default** and the template injects
  `<|think|>` itself. The six `SYSTEM <|think|>` Modelfile directives were an Ollama workaround (Ollama never runs the
  Jinja) and have no llama.cpp equivalent - `llama-server --help` has no system-prompt flag across all 647 lines.
- Same mechanism closes the standing TODO at `modelfiles/qwen3.6/35b-a3b-mtp-ud-q5-k-xl/Modelfile:5` ("figure out how
  to automate/enforce/display whether think=true"): the instruct-mode entry sets
  `--chat-template-kwargs '{"enable_thinking":false}'` as a launch flag.
- Probe before Phase 2 writes nine Gemma entries: confirm a thought channel actually appears, and confirm what
  `-rea on|off|auto` does to the kwarg (this session verified the default and the override path, not the flag mapping).
- Google also states multi-turn history must strip prior thoughts except during function calling. llama.cpp exposes
  `--reasoning-preserve` / `--no-reasoning-preserve` (default: template default); unsloth documents
  `--chat-template-kwargs '{"preserve_thinking":true}'`. Which default the fleet wants is unprobed.

## Sampling divergences

- **`min_p` injection.** Bare llama-server injects `min_p 0.05` into requests that omit it
  (`docs/history/2026-07-17-llamacpp-eval.md:67`). All 15 Qwen-family Modelfiles pin `min_p 0.0`; **no Gemma Modelfile
  sets `min_p` at all** (9 files), and `ollama show --parameters gemma4-12b-it-qat` lists none. Migrating without an
  explicit value silently changes Gemma sampling.
  - Neither Google nor unsloth specifies a `min_p` for Gemma 4. Decision: pin `0.0` on Gemma entries as a repo choice
    to preserve current behavior, recorded as such rather than as a vendor value.
- **`presence_penalty` for Qwen thinking-general is model-specific, not stale.** Verified against raw READMEs, not
  rendered pages:
  - `Qwen/Qwen3.6-35B-A3B` (MoE) thinking-general: `presence_penalty=1.5`.
  - `Qwen/Qwen3.6-27B` (dense) thinking-general: `presence_penalty=0.0`.
  - Both cards agree: thinking-coding `0.0`, instruct/non-thinking `1.5`.
  - Qwen's own caveat: "you can adjust the `presence_penalty` parameter between 0 and 2 to reduce endless repetitions.
    However, using a higher value may occasionally result in language mixing and a slight decrease in model
    performance."
  - Qwen's READMEs are additionally self-inconsistent: `Qwen/Qwen3.5-9B` discussion #51 reports the same card giving
    `top_p` 0.95 vs 1.0, `top_k` 20 vs 40, `presence_penalty` 1.5 vs 2.0 in different sections. Opened April 16, no
    maintainer response.
  - Fleet impact is exactly one entry: of the three on the general-thinking profile
    (`qwen3.5/queen-27b-reasoning-q4-k-m`, `qwen3.6/27b-obliterated-q4-k-m`,
    `qwen3.6/35b-a3b-mtp-reasoning-ud-q5-k-xl`), only the last is 35B-A3B lineage, so only it diverges from its own
    card. It is the Codex driver (`docs/history/2026-07-23-llamacpp-migration-planning.md:57`).
  - Decision: keep `0.0` through the migration so cutover stays sampling-neutral and any behavior change is
    attributable to the engine; benchmark `1.5` vs `0.0` on that entry as a post-migration follow-up.
- Qwen recommends "an output length of 32,768 tokens for most queries" (81,920 for competition-grade problems); the
  fleet pins `num_predict 65536`. Between the two, not a mandate violation - noted, unchanged.

## Serving flags

- `-fa on` appears in both vendors' recommended llama.cpp commands (unsloth `gemma-4-12B-it-qat-GGUF` and
  `Qwen3.6-35B-A3B-MTP-GGUF`), matching the repo's inherited `FLASH_ATTENTION=1`.
- Neither vendor specifies a KV cache type. The repo's `KV_CACHE_TYPE=q8_0` is inherited fleet-wide from the Ollama
  service env (`AGENTS.md`), and `docs/parameters.md` covers sampling only - so the migration had no home for these
  flags at all.
- A third-party KL-divergence benchmark (~250k tokens across six categories, three runs per model, BF16 GGUFs, f16 vs
  q8_0 vs q4_0 cache) reports q8_0 cache KL of **0.108 on Gemma 31B** and **0.377 on Gemma 26B A4B** against **<0.04
  on Qwen 27B and Qwen 35B-A3B**, concluding "'q8_0 is practically lossless' is wrong for Gemma".
  - Validity: single source, not peer-reviewed; tested on BF16 GGUFs while the fleet runs QAT/UD quants; the author
    notes results reflect llama.cpp's TurboQuant-inspired attention rotation. A lead, not a finding.
  - Decision: probe on-box before the Phase 1 ctx ladder, since KV type changes the VRAM math the ladder measures.
    The ladder must then run at whichever type is chosen.

## MTP details

- Draft depth is per-family in vendor docs: unsloth's `gemma-4-12B-it-qat-GGUF` card gives
  `--spec-type draft-mtp --spec-draft-n-max 4`; the `Qwen3.6-35B-A3B-MTP-GGUF` card gives `--spec-draft-n-max 2`. All
  10 MTP Modelfiles currently pin `draft_num_predict 2`.
  - Decision: keep `2` fleet-wide through the migration (behavior-preserving); test `4` for Gemma in the benchmark
    suite afterwards.
- unsloth's Gemma card states "The model auto-discovers the MTP drafter, so no separate `--model-draft` parameter is
  needed". That claim is for `-hf` loading; the fleet loads pinned local snapshot paths, so explicit drafter wiring is
  assumed until probed.
- **`--mmproj` and MTP are documented as mutually exclusive.** The `Qwen3.6-35B-A3B-MTP-GGUF` card states `-np > 1` and
  `--mmproj` are "not yet supported with MTP".
  - Three surviving fleet entries configure both (an `mmproj-BF16.gguf` `FROM` line plus `draft_num_predict`):
    `qwen3.6/35b-a3b-mtp-ud-q5-k-xl`, `qwen3.6/27b-mtp-coding-ud-q4-k-xl`, `qwen3.5/9b-mtp-coding-ud-q4-k-xl`.
  - Two have a surviving non-MTP vision sibling (`27b-coding-ud-q4-k-xl`, `9b-coding-ud-q4-k-xl`); the 35B-A3B q5 does
    not, because the non-MTP 35B lane is on the prune list.
  - Decision: probe on b9860 first. If the conflict is real, keep both capabilities by giving the affected GGUF two
    router entries - one MTP entry without `--mmproj`, one vision entry with `--mmproj` and no drafter flags. Entries
    are preset sections, so a second entry costs no additional disk.
- `-np 1` appears in the vendor MTP command and in the eval's stock configuration; the preset should state it rather
  than inherit it.

## Provenance and validity

- On-box: binary versions and timestamps, `build/CMakeCache.txt`, b9860 source reads at every cited `file:line`,
  `llama-server --help` on the pin, GGUF chat-template extraction via a byte-offset read of the embedded
  `tokenizer.chat_template`, `ollama show --parameters`, and greps over `modelfiles/`.
- Web: Google Gemma 4 thinking and prompt-formatting docs, unsloth Gemma 4 / Qwen3.6 model pages and the
  `gemma-4-12B-it-qat-GGUF` and `Qwen3.6-35B-A3B-MTP-GGUF` cards, Qwen `Qwen3.6-35B-A3B` and `Qwen3.6-27B` raw
  READMEs, Qwen3.5-9B discussion #51, and one third-party KV-cache KL benchmark.
- Point-in-time 2026-07-25, single box. The template extraction covers the 12B QAT GGUF only; other Gemma GGUFs are
  assumed to share it and are unverified.
- UNVERIFIED pending probes: Gemma thinking on the wire, `-rea` flag mapping, `preserve_thinking` default, KV cache
  type on our quants, MTP x `--mmproj` behavior on b9860, and Gemma drafter auto-discovery from local paths.
