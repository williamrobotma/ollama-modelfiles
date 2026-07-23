# 2026-07-23: llamacpp-migration planning session evidence

Planning session for `specs/llamacpp-migration`: spec vetted, plan.md filled, no execution, no GPU loads.
Method: 5 research workflows (34 agents, each fan-out followed by an opus adversarial verification pass), the claude-code-guide docs agent, on-box wire captures and source reads, and a full-context Fable second-opinion advisor.

## Watch items re-verified (GitHub API, adversarially confirmed)

- #24795 open (last activity 2026-06-30); #24443 open (2026-06-23); no commit in repo history references either.
- PR #24942 (fix candidate): open, zero maintainer reviews; rebased 2026-06-29; reported working on ROCm hardware.
- #25873: closed `not_planned` 24 minutes after opening; a 2026-07-22 comment confirms the crash persists - treat as live.
- #25986: open; maintainer demands a curl repro ("Any further communication without producing this will be ignored").
- Master delta since b9860 (fdb1db877): latest tag b10094 (2026-07-23); zero commits since 2026-07-16 on gemma4*.cpp, speculative.cpp, server-chat.cpp, server.cpp, chat-parser.cpp; one unrelated chat.cpp commit.
- New same-family crash reports on NEWER builds: #26017 (Gemma E4B MTP, b10090), #25828 (b10012/b10059, closed, resolution unknown). New correctness item: #25618 (draft-MTP greedy divergence on quantized targets).
- Net: staying pinned on b9860 costs nothing and avoids fresh exposure.
- PR #25707 (ternary gate, "CUDA: add Q2_0 support"): open, `mergeable_state: blocked`, needs rebase per 2026-07-22 comment, no maintainer review.

## Router mode and llama-swap

- b9860 router flags on-box (`common/arg.cpp:3221-3243`): `--models-dir/-preset/-max/-autoload`; no TTL flag exists on pin or master.
- Keep-alive analog: `--sleep-idle-seconds` (`arg.cpp:3376`; README: unloads model+KV on idle, works in multi-model mode; PR #18228).
- `--models-max` eviction policy undocumented (verifier-confirmed absence in README and arg.cpp).
- Router children spawn from the router's own executable (`tools/server/server-models.cpp:102,259-265`); no per-model binary key -> single-engine.
  - Consequence: bonsai decision 1 = "build the PrismML fork" would force llama-swap or a second port; "wait for #25707" keeps router sufficient.
- Field evidence thin but one-directional: Level1Techs daily-use report (2026-01, "Ollama is basically obsolete now", sole complaint = restart to pick up new models); HN "don't even need llama-swap anymore" (2026-03); no reverse migrations found.
- Router bug reports #22847 (multi-model crash), #20137 (models-max race), #23096 (/metrics autoload) are all `bug-unconfirmed`, stale-bot-closed, from multi-user setups.
- #18129 (frontend sampling overrides router presets) was fixed 2026-03-19 - inside our pin.
- llama-swap: v241 (2026-07-22) adds nothing Anthropic-relevant; open races #635 (empty 400 mid-swap) and #946 (TTL unload deadlock, filed 2026-07-23); `/v1/responses` proxying unverified.
- Advisor verdict: at a one-user profile the confirmed-open TTL bug outweighs router's untriaged reports; llama-swap = named contingency, config ports in ~half a day.

## Web search mechanism (the load-bearing discovery)

- Claude Code sends all 27 tools as client tools (input_schema) to a custom `ANTHROPIC_BASE_URL` - verified by pointing `claude -p` at a local capture stub.
- WebSearch is fulfilled by a sub-request to the SAME base URL carrying exactly one tool, `{"name":"web_search","type":"web_search_20250305"}`, prompt "Perform a web search for the query: ..." - verified by streaming a fake tool_use from the stub and capturing the follow-ups.
- Ollama executes that tool daemon-side: `middleware/anthropic.go` hasWebSearchTool -> WebSearchAnthropicWriter -> `anthropic.WebSearch` -> hardcoded `https://ollama.com/api/web_search`, auth.Sign key material, max 3 loops; binary strings on the installed 0.31.2 daemon corroborate.
- Scope: `/v1/messages` only. `/api/chat` and `/v1/chat/completions` have zero interception (verifier grep of middleware/openai.go and routes.go). "One URL = model + search" is an Ollama-middleware property, not a protocol given.
- Stock llama-server b9860: the Anthropic conversion blind-converts any tools[] entry to a function tool with empty schema (`tools/server/server-chat.cpp:477-494`) -> the sub-request would yield silently fabricated "results". The Responses conversion skips non-function tool types with a warning (`:260-267`).
- OpenCode: `ollama launch opencode` wires only a provider baseURL at `/v1` (cmd/launch/opencode.go); on-box `opencode.jsonc` is empty and `OPENCODE_ENABLE_EXA` unset - the belief that OpenCode gets search via Ollama is unsupported; execution records which tool actually fires.
- Community reconciliation: deny-builtin + MCP search server is the dominant pattern; llama.cpp declined built-in search (#24798, closed via a WebUI-only MCP dialog); LiteLLM `websearch_interception` is the only verified literal one-URL preserver (gateway daemon, no web_fetch interception); z.ai and MiniMax also don't execute web_search_20250305 and ship MCP bolt-ons instead.
- Chosen: Ollama web-search MCP - REST `https://ollama.com/api/web_search` + `/api/web_fetch`, standalone with `OLLAMA_API_KEY`, no daemon needed; documented clients Cline/Codex/Goose; Claude Code as generic stdio client validated at execution. Fallback: `@brave/brave-search-mcp-server` (the `@modelcontextprotocol/server-brave-search` package is deprecated; Brave free tier became $5/mo metered 2026-02).
- MCP-for-Claude-Code feasibility docs-verified (code.claude.com/docs/en/mcp.md); scoped disable via `--disallowedTools WebSearch`.

## Client wire-protocol matrix (verified from primary docs)

- Claude Code: Anthropic `/v1/messages`; native at b9860 incl. the cch-stamp prefix-cache normalization.
- Open WebUI: OpenAI `/v1/chat/completions`; Brave search is client-side (webui.db), result-RAG uses the local MiniLM embedder.
- Codex CLI: `/v1/responses` only ("responses is the only supported value"; chat wire removed ~2026-02).
  - web_search default-on (Cached) but client-gated off for non-catalog models (`supports_search_tool` defaults false) - clean omission, no hollow tool.
  - Hard-fail mode: replaying OpenAI-originated `web_search_call` history at a local server 400s (#24612, open) -> fresh threads per provider.
  - Live risk: tool calls vs llama.cpp Responses (#26977 open, MCP tools "unsupported call"; #10635 closed, resolution unknown).
- OpenCode: `@ai-sdk/openai-compatible` at `/v1`; llama.cpp documented by name; per-model `limit.context/output` set manually; all tools client-executed.
- VS Code Copilot: BYOK "Custom Endpoint" provider (2026-06) with Chat/Responses/Messages apiTypes; all agent tools client-executed; `toolCalling: true` gate; works without a Copilot plan -> `specs/copilot-byok`.
- Pi (earendil-works/pi): `~/.pi/agent/models.json`, `openai-completions` and documented `anthropic-messages` api types; no built-in web tools by design.

## Prune evidence

- Open WebUI usage (webui.db, read-only): 7 chats ever, all Gemma-family, newest 2026-06-24.
- `~/.ollama/config.json`: claude integration -> `qwen3.6-35b-a3b-mtp-coding-ud-q5-k-xl`; codex -> mtp-reasoning q5; opencode -> mtp-coding q5; `last_model` = 31B heretic (recent `ollama run` use).
- HF-cache diff vs Modelfile FROM/DRAFT paths: `models--noctrex--Qwopus3.5-9B-Coder-MTP` (15G) referenced by nothing.
- Alias graph: both 35B MTP aliases already point at q5; the non-MTP q4 35B lane is used by no integration.
- User decisions: prune orphan + superseded q4 pair + non-MTP 35B lane (~60G); keep uncensored sets, Gemma extras, 31B lane.

## Provenance and validity

- Workflows: upstream-delta (13 agents), switching-practice (5), client-compat (5), server-tools (4), ollama-websearch-parity (5), websearch-reconciliation (3); every load-bearing claim re-fetched by an opus adversarial verifier.
- Refutations applied: #18129 is fixed not open; the ubergarm quote is hearsay not a migration report; `@modelcontextprotocol/server-brave-search` is deprecated; z.ai's MCP path is `web_search_prime`; MiniMax's exact failure mode is unestablished.
- On-box: capture-stub `claude -p` runs (bodies in session scratchpad, not retained), `strings` on the ollama 0.31.2 and claude binaries, b9860 source reads at the file:line cites above, read-only webui.db query.
- Single box, single day; upstream states are point-in-time (2026-07-23), re-checked at execution per the spec's rules. UNVERIFIED pending execution probes: Claude Code as a client of the Ollama web-search MCP, and OpenCode's actual search-tool behavior.
