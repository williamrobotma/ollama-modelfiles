# ollama-modelfiles

Local LLM serving config for a single 12 GB GPU, organized by model family and use profile.
The live serving stack is stock llama.cpp in router mode ([llamacpp/](llamacpp/README.md), port 11433).
The repo name is historical: the Ollama build layer it is named for was retired and removed at the 2026-08-12 purge.
Every served GGUF is a pinned Hugging Face cache snapshot (`hf download`; mostly [Unsloth](https://unsloth.ai) builds).
Agents should read [AGENTS.md](AGENTS.md) first.

## Requirements

- A stock llama.cpp build. The build record is defined in the header comment of `llamacpp/launch.sh`.
  - The rebuild rule is in `specs/llamacpp-migration/spec.md`'s Rules section.
- The Hugging Face CLI (`hf`, from `huggingface_hub`) to provision GGUFs.
- An NVIDIA CUDA GPU (reference box: RTX 4070, 12 GB, WSL2). Models larger than ~12 GB partial-offload to CPU.
  - The CUDA version mandates are in [docs/parameters.md](docs/parameters.md).

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

Served ids and pinned snapshot paths are defined in `llamacpp/models.ini`.
The pinning convention and add-a-model procedure are in [llamacpp/README.md](llamacpp/README.md).

## Model catalog

The served fleet is defined by `llamacpp/models.ini`, which also holds each entry's serving flags.
List the live ids with `curl -s 127.0.0.1:11433/v1/models`.
The fleet spans these families:

- Gemma 4: thinking, with vision via mmproj.
- Qwen 3.6 coders.
- Qwen 3.5 small coders. Qwen 3.6's smallest GGUF is 27B (it partial-offloads), so the fully-resident
  coders are Qwen 3.5 dense.
- An uncensored track of community "abliterated" builds - finetunes with refusal behavior removed
  (plain Q4/i1-Q4, not UD-*). Abliteration can degrade reasoning and tool-calling.
  - Verify on-task. All of them must pass the [chat-template gate](AGENTS.md#chat-template-gate-for-community-ggufs).

Ids no longer carry quant tags. The quant appears only in the `model =` path.
Aliases now serve only profile defaults.

### Roadmap

- [ ] Qwen 3.8 support (pending official release of open weights)

## Quantization

Canonical Unsloth models use an Unsloth Dynamic ("UD-") quant, which is not standard llama.cpp Q4_0:

- **UD-** = Unsloth Dynamic: every layer gets a custom quant type based on a 1.5M+ token calibration set.
- **Q4_K_XL / Q5_K_XL** = the **XL** suffix keeps embedding and output weights at Q8_0 for better accuracy.
- Gemma 4 QAT repos publish only UD-Q4_K_XL (QAT already targets ~Q4).
  - Standard Q4_0 degrades Top-1 from ~89% to ~74% and is larger.
- Community abliterated models are not Unsloth, so their tags are plain Q4_K_M or i1-Q4_K_M, not UD-*.
- See [Unsloth Dynamic 2.0 GGUFs](https://unsloth.ai/docs/basics/unsloth-dynamic-2.0-ggufs).

Sampling profiles (Gemma thinking, Qwen precise-coding/general/instruct) are defined in
[docs/parameters.md](docs/parameters.md).

## Web search

Local models have no web access of their own; `claude-local` sessions get it from one MCP server.

- The server: `llamacpp/mcp/web-search-mcp.py`, which calls **Ollama's hosted web-search API** (a cloud service on `ollama.com`).
- The key: `OLLAMA_API_KEY`, read from `~/.config/claude-local.env` (mode 600) - it never enters this repo.
- **Brave is not involved in claude-local's search.** A swap to a Brave-backed MCP is planned in `specs/brave-search-mcp`.
  - The one place Brave does appear: Open WebUI's own in-app search feature uses a Brave key, client-side.
- This cloud API is the one remaining Ollama dependency; the local Ollama serving stack is retired.
- Wiring and provenance: [llamacpp/mcp/README.md](llamacpp/mcp/README.md).

## Repo map

| Path | What |
|---|---|
| `llamacpp/` | The live serving stack: `models.ini` preset, `launch.sh`, pinned templates, vendored MCP. |
| `docs/` | Topic docs; `docs/history/` holds immutable dated session logs. |
| `specs/<feature>/` | Spec + tasks (plus plan when needed) for in-flight work; executed by the run-spec skill. |
| `specs/done/<feature>/` | Completed bundles (spec.md Acceptance met), filed here by the run-spec skill. |
| `AGENTS.md` / `CLAUDE.md` | Canonical agent instructions (incl. the claude-local spec); CLAUDE.md is `@AGENTS.md`. |

## Benchmarking

The Ollama-era benchmark suites were removed at the 2026-08-12 purge; git history preserves them.
The distilled findings and the GPU resource-capture procedure stay live in [docs/benchmarking.md](docs/benchmarking.md).

## More

- [AGENTS.md](AGENTS.md) - conventions and commands for any coding agent.
- [docs/architecture.md](docs/architecture.md) - how the stack fits together.
- [docs/parameters.md](docs/parameters.md) - sampling profiles and mandates.
- [docs/openwebui.md](docs/openwebui.md) - the browser frontend.
- [docs/history/index.md](docs/history/index.md) - the research trail.
