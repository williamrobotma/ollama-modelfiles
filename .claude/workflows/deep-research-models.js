export const meta = {
  name: 'deep-research-models',
  description: 'Research current best local LLM models for Ollama use cases',
  phases: [
    { title: 'Search', detail: '5 parallel search agents' },
    { title: 'Fetch', detail: 'URL-dedup, fetch sources' },
    { title: 'Verify', detail: '3-vote adversarial verification' },
    { title: 'Synthesize', detail: 'Merge, rank, cite' },
  ],
}

// Phase 1: Search angles
const ANGLES = [
  { key: 'coding', prompt: 'Best coding LLMs for local Ollama inference as of July 2026. New releases, benchmarks, GGUF quant availability. Focus on models comparable to or better than Qwen3.6-27B/35B-coding and Qwen3.5-9B-coding. Include any newer Qwen variants, DeepSeek-Coder releases, Llama 4, or other coding-specialized models. Look for HuggingFace GGUF downloads and Ollama compatibility.' },
  { key: 'reasoning', prompt: 'Best reasoning/agentic LLMs for local Ollama inference as of July 2026. New releases beyond Gemma 4 and Qwen3.6. Look for models with strong reasoning capabilities that work well with Claude Code / agentic workflows. Consider abliterrated variants, distilled models, and any new reasoning-focused releases. Focus on models that fit in ~16-24GB VRAM or have efficient MoE variants.' },
  { key: 'small', prompt: 'Best small local LLMs (under 13B params, fitting in 12GB VRAM) for Ollama as of July 2026. New releases beyond Qwen3.5-9B-coding and Gemma 4 12B. Look for newer 8B-10B class models, improved quantizations, or any new small-model releases. Consider coding, general reasoning, and versatile models.' },
  { key: 'moe', prompt: 'Best Mixture-of-Experts (MoE) LLMs for local Ollama inference as of July 2026. New releases beyond Gemma 4 26B-A4B. Look for efficient MoE models with small active parameter counts, good quality-to-cost ratio. Consider Mixtral successors, Qwen MoE variants, and any new MoE releases. Focus on models that fit in 16-24GB VRAM with good performance.' },
  { key: 'general', prompt: 'Notable new LLM releases and GGUF quantizations as of June-July 2026 for local inference. Any models worth tracking that don\'t fit coding/reasoning/small/MoE categories. Look for general-purpose models with strong benchmarks, new architectures, or interesting capabilities. Focus on models with available GGUF downloads and Ollama compatibility.' },
]

log('Phase 1: Running 5 parallel searches')
const searchResults = await parallel(ANGLES.map((angle, i) => () =>
  agent(angle.prompt, {
    label: `search:${angle.key}`,
    phase: 'Search',
  })
))

log('Phase 2: Fetching top sources from search results')
// Collect all URLs from search results
const allUrls = []
for (const sr of searchResults) {
  if (sr) {
    // Extract URLs from search results text
    const urlMatches = sr.matchAll(/https?:\/\/[^\s<>"'`,;)]+/g)
    for (const m of urlMatches) {
      allUrls.push(m[0])
    }
  }
}

// Deduplicate and limit
const uniqueUrls = [...new Set(allUrls)].slice(0, 30)
log(`Found ${uniqueUrls.length} unique URLs to fetch`)

log('Phase 3: Fetching and extracting claims')
const fetchedClaims = []
for (const url of uniqueUrls) {
  try {
    const content = await WebFetch(url, 'Extract all factual claims about LLM models, benchmarks, model names, parameters, release dates, GGUF availability, Ollama compatibility, and performance numbers. Be exhaustive.')
    if (content) {
      fetchedClaims.push({ url, content })
    }
  } catch (e) {
    log(`Failed to fetch ${url}: ${e.message}`)
  }
}

log('Phase 4: Verifying claims')
const verificationTasks = []
for (const fc of fetchedClaims) {
  // Extract specific model claims and verify each
  const modelNames = fc.content.matchAll(/[A-Za-z0-9]+[\-\/][A-Za-z0-9.\-]+(?:\d+[BMK]+)/g)
  for (const m of modelNames) {
    const modelName = m[0]
    verificationTasks.push({ url: fc.url, modelName, content: fc.content })
  }
}

log('Phase 5: Synthesizing findings')
const synthesis = await agent(
  `Synthesize the research findings into a report on current best local LLM models for Ollama.

User's use cases (from their Ollama modelfiles repo):
1. **Coding**: Currently uses Qwen3.6-27B/35B-MTP-coding and Qwen3.5-9B-coding
2. **Reasoning/Agentic**: Currently uses Gemma 4 12B/26B-A4B-IT, abliterated variants
3. **Small 12GB-resident**: Currently uses Qwen3.5-9B-coding, Gemma 4 12B
4. **MoE efficiency**: Currently uses Gemma 4 26B-A4B (~3.8B active params)
5. **Uncensored**: Currently uses various abliterated variants

Based on the fetched sources, identify:
- Models that beat current favorites in benchmarks
- New releases that could replace existing choices
- Interesting models worth trying
- Any important caveats (CUDA compatibility, VRAM requirements, quant availability)

Structure as:
1. Top recommendations by use case with confidence levels
2. Models to try (interesting new releases)
3. Caveats and gotchas
4. Sources cited`,
  { label: 'synthesize' }
)

log('Research complete')
return synthesis
