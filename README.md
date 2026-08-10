# ollama-modelfiles

Local LLM serving config for a single 12 GB GPU, organized by model family and use profile.
The live lane is stock llama.cpp in router mode ([llamacpp/](llamacpp/README.md), port 11433).
The Ollama Modelfiles are the retired legacy build layer, frozen on disk until the post-migration purge.
The 2026-07-27 fleet reduction already deleted 8 of them (a recorded spec supersede, not freeze drift).
Every served GGUF is a pinned Hugging Face cache snapshot (`hf download`; mostly [Unsloth](https://unsloth.ai) builds).
Agents should read [AGENTS.md](AGENTS.md) first.

## Requirements

- A stock llama.cpp build; the build record is single-homed in the header comment of `llamacpp/launch.sh`.
  - The rebuild rule lives in `specs/llamacpp-migration/spec.md`'s Rules section.
- The Hugging Face CLI (`hf`, from `huggingface_hub`) to provision GGUFs.
- An NVIDIA CUDA GPU. The reference box is an RTX 4070 (12 GB, WSL2); models larger than ~12 GB partial-offload to CPU. Use CUDA 13.1 or 13.3 - 13.2 corrupts Gemma 4 output.

## Quickstart

```bash
# 1. Clone
git clone <this repo> && cd ollama-modelfiles

# 2. Download one model's GGUFs into the HF cache (weights + vision projector)
hf download unsloth/gemma-4-12B-it-qat-GGUF \
    gemma-4-12B-it-qat-UD-Q4_K_XL.gguf mmproj-BF16.gguf

# 3. Serve the fleet (every preset entry, 127.0.0.1:11433)
llamacpp/launch.sh

# 4. Chat (any OpenAI or Anthropic client; Open WebUI runs on :8080)
curl 127.0.0.1:11433/v1/chat/completions -d '{"model":"gemma4-12b-it-qat","messages":[{"role":"user","content":"hi"}]}'
```

Step 3 above runs in the foreground for a quick check.
For persistent serving, see the runbook in [docs/architecture.md](docs/architecture.md#4-serving-layer-and-its-clients).

Served ids and pinned snapshot paths live in `llamacpp/models.ini`.
The pinning convention and add-a-model procedure are in [llamacpp/README.md](llamacpp/README.md).

## Model catalog

The served fleet is defined by `llamacpp/models.ini` - 18 configs + 1 alias name as of 2026-08-09.
List the live ids with `curl -s 127.0.0.1:11433/v1/models`; each entry's serving profile lives in the INI itself.
Families: Gemma 4 (thinking; vision via mmproj), Qwen 3.6 coders, Qwen 3.5 small coders, and an uncensored track.

- Small coders: Qwen 3.6's smallest GGUF is 27B (offloads), so the resident coding line is Qwen 3.5 dense.
- Uncensored: community abliterated builds (plain Q4/i1-Q4, not UD-*); abliteration can dent reasoning/tool-calling.
  - Verify on-task; all must pass the [chat-template gate](AGENTS.md#chat-template-gate-for-community-ggufs).
- Ids no longer carry quant tags (the quant lives only in the `model =` path); aliases now serve only profile-defaults.

### Roadmap

- [ ] Qwen 3.8 support (pending official release of open weights)

## Quantization

Canonical Unsloth models use an Unsloth Dynamic ("UD-") quant, which is not standard llama.cpp Q4_0:

- **UD-** = Unsloth Dynamic: every layer gets a custom quant type based on a 1.5M+ token calibration set.
- **Q4_K_XL / Q5_K_XL** = the **XL** suffix keeps embedding and output weights at Q8_0 for better accuracy.
- Gemma 4 QAT repos publish only UD-Q4_K_XL (QAT already targets ~Q4); standard Q4_0 degrades Top-1 from ~89% to ~74% and is larger.
- Community abliterated models are not Unsloth, so their tags are plain Q4_K_M or i1-Q4_K_M, not UD-*.
- See [Unsloth Dynamic 2.0 GGUFs](https://unsloth.ai/docs/basics/unsloth-dynamic-2.0-ggufs).

Sampling profiles (Gemma thinking, Qwen precise-coding/general/instruct) live in [docs/parameters.md](docs/parameters.md).

## Repo map

| Path | What |
|---|---|
| `llamacpp/` | The live serving lane: `models.ini` preset, `launch.sh`, pinned templates, vendored MCP. |
| `modelfiles/<family>/<stem>/Modelfile` | Legacy Ollama build layer (frozen until purge); name = `<family>-<stem>`. |
| `scripts/` | `ollama-create.sh` (legacy build), `repro-mtp-graphs.sh` (crash repro). |
| `benchmarks/` | Three frozen-Ollama suites + `llamacpp-parity` (live engine), shared `common.sh`, `report.py`, `all.sh`. |
| `docs/` | Topic docs; `docs/history/` holds immutable dated session logs. |
| `specs/<feature>/` | Spec + tasks (plus plan when needed) for in-flight work; executed by the run-spec skill. |
| `specs/done/<feature>/` | Completed bundles (spec.md Acceptance met), filed here by the run-spec skill. |
| `AGENTS.md` / `CLAUDE.md` | Canonical agent instructions; thin Claude-specific shim. |

## Benchmarking

Three dry-run-by-default suites (`qwen`, `gemma`, `9b-coders`) time decode throughput against the retired Ollama lane.
The cross-engine `llamacpp-parity` suite covers the live lane. Nothing runs without `--execute`.

```bash
benchmarks/qwen/run.sh            # print the plan (dry-run)
benchmarks/qwen/run.sh --execute  # run it
```

Ports, isolated serves, and distilled findings (MTP speedups, the CUDA-graphs crash, throughput costs): [docs/benchmarking.md](docs/benchmarking.md).

## More

- [AGENTS.md](AGENTS.md) - conventions and commands for any coding agent.
- [docs/architecture.md](docs/architecture.md) - how the stack fits together.
- [docs/parameters.md](docs/parameters.md) - sampling profiles and mandates.
- [docs/openwebui.md](docs/openwebui.md) - the browser frontend.
- [docs/history/index.md](docs/history/index.md) - the research trail.
