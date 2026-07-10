export const meta = {
  name: 'openwebui-ollama-env-research',
  description: 'Live research: Open WebUI setup w/ ollama+Brave+tools; ollama 0.31.1 env defaults; API-key semantics',
  phases: [
    { title: 'Research', detail: '4 parallel finders' },
    { title: 'Verify', detail: 'adversarial re-check of load-bearing claims' },
  ],
}

const FINDINGS = {
  type: 'object',
  required: ['summary', 'findings', 'recommendation'],
  properties: {
    summary: { type: 'string' },
    findings: { type: 'array', items: { type: 'object', required: ['claim', 'evidence_url', 'as_of'], properties: {
      claim: { type: 'string' }, evidence_url: { type: 'string' }, as_of: { type: 'string' },
      confidence: { type: 'string', enum: ['high', 'medium', 'low'] } } } },
    recommendation: { type: 'string' },
  },
}
const VERDICT = {
  type: 'object',
  required: ['verdicts', 'overall_trust'],
  properties: {
    verdicts: { type: 'array', items: { type: 'object', required: ['claim', 'verdict', 'why'], properties: {
      claim: { type: 'string' }, verdict: { type: 'string', enum: ['confirmed', 'refuted', 'unverifiable'] },
      why: { type: 'string' }, correction: { type: 'string' } } } },
    overall_trust: { type: 'string', enum: ['high', 'medium', 'low'] },
  },
}

const COMMON = `Today is ${args.today}. Research LIVE/current state (docs, github, release notes as of this week). Box: Linux WSL2, RTX 4070 12GB, ollama 0.31.1 via systemd (OLLAMA_API_KEY set, KEEP_ALIVE=24h, FLASH_ATTENTION=1, KV_CACHE_TYPE=q8_0; NUM_PARALLEL and CONTEXT_LENGTH env recently REMOVED/commented). Open WebUI installed via pipx (user 'wma'), not yet configured/run. Cite exact URLs; prefer primary sources (docs.openwebui.com, github.com/open-webui/open-webui, github.com/ollama/ollama code+docs). Return structured data only.`

const QUESTIONS = [
  { key: 'openwebui-setup', prompt: `${COMMON}
QUESTION: Current (mid-2026) best-practice Open WebUI setup for a pipx install serving as frontend to a local systemd ollama at 127.0.0.1:11434. Find: (1) latest open-webui version + any breaking config changes in recent releases; (2) recommended way to run persistently for a single user on Linux WSL2 (systemd --user unit vs 'open-webui serve' + which env: DATA_DIR, PORT, WEBUI_AUTH single-user mode); (3) how to point it at ollama: OLLAMA_BASE_URL(S) env exact names TODAY, and how to pass a bearer/API key to ollama if the ollama server requires Authorization (does open-webui support per-connection auth headers for the OLLAMA connection type - UI 'Manage Ollama API Connections' with key field?); (4) does open-webui still bundle its own inference (it uses ollama or openai-compatible endpoints only)?; (5) pipx upgrade path + python version constraints.` },
  { key: 'openwebui-brave-tools', prompt: `${COMMON}
QUESTION: Open WebUI web search + tool calling, current config. Find: (1) exact env var / Admin-Settings names TODAY to enable Brave as the web search engine (historically WEB_SEARCH_ENGINE / RAG_WEB_SEARCH_ENGINE=brave + BRAVE_SEARCH_API_KEY - confirm current names + UI path Admin Panel > Settings > Web Search); (2) whether web search works with ollama-backend models and what RAG/embedding config it needs by default (default embedding model download - does it need internet/HF at first run?); (3) native tool calling with ollama models: what's required (model capability 'tools', 'Native' vs 'Default' function-calling mode per-model setting), known issues with qwen3.x/gemma4 tool templates in open-webui; (4) any Brave API free-tier constraints relevant to personal use (rate limits, key types: 'Data for Search' vs 'Data for AI').` },
  { key: 'ollama-env-defaults', prompt: `${COMMON}
QUESTION: ollama 0.31.1 exact server defaults, from code/docs (github.com/ollama/ollama envconfig or server source at tag v0.31.1, or current docs/faq): (1) OLLAMA_NUM_PARALLEL default when unset (auto? fixed 1? memory-based) and its interaction with KV cache size / context allocation; (2) OLLAMA_CONTEXT_LENGTH default when unset (4096? model-dependent?) AND precedence vs Modelfile 'PARAMETER num_ctx' vs API options.num_ctx - which wins for /api/chat and for the OpenAI-compat endpoint; (3) OLLAMA_KV_CACHE_TYPE=q8_0 + OLLAMA_FLASH_ATTENTION=1 interactions (q8_0 KV requires flash attention? per-model exceptions where FA is auto-disabled e.g. gemma/qwen hybrid attention?); (4) with NUM_PARALLEL unset and a Modelfile num_ctx=131072-262144 on 12GB VRAM: does ollama multiply ctx allocation by parallel slots (n_ctx = num_ctx * num_parallel)? Cite envconfig.go / sched.go / server docs lines.` },
  { key: 'ollama-apikey-semantics', prompt: `${COMMON}
QUESTION: OLLAMA_API_KEY semantics in ollama 0.31.x - this env is SET on the user's systemd server. From ollama source/docs/release notes: (1) does setting OLLAMA_API_KEY on the SERVER enforce inbound Authorization on /api/* and /v1/* (401 without bearer)? Or is OLLAMA_API_KEY a CLIENT-side var (used by 'ollama launch'/cloud/signin) with server auth done differently? Distinguish from ollama.com cloud API keys. Find the exact commit/release that introduced OLLAMA_API_KEY and what reads it; (2) if inbound auth IS enforced: exact header format expected; (3) implications: do local clients (open-webui, claude-local via 'ollama launch claude' Anthropic endpoint, curl to /api/tags) need the key, and is localhost exempt; (4) does 'ollama launch claude' (claude-local flow) still work when API key auth is on, and where does claude code's ANTHROPIC_BASE_URL point in that flow.` },
]

phase('Research')
const results = await pipeline(
  QUESTIONS,
  q => agent(q.prompt, { label: `find:${q.key}`, phase: 'Research', schema: FINDINGS }),
  (res, q) => {
    if (!res) return null
    const claims = res.findings.map(f => `- ${f.claim} [${f.evidence_url}]`).join('\n')
    return agent(`${COMMON}
Adversarial verifier for question "${q.key}". Researcher's claims:
${claims}
Recommendation: ${res.recommendation}
Re-check the 3-5 most load-bearing claims against primary sources yourself (fetch the URLs or better ones; for env/config names fetch the actual docs page or source file at the current version). Refute anything stale or misread; give corrections.`,
      { label: `verify:${q.key}`, phase: 'Verify', schema: VERDICT },
    ).then(v => ({ key: q.key, research: res, verification: v }))
  },
)
return results.filter(Boolean)
