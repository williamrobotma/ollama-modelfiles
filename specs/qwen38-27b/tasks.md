# Tasks: qwen38-27b

Status legend: [ ] pending, [x] done. Resume point for this feature.

- [x] Scaffolded 2026-09-20 (no spec.md; the open-weights blocker lifting is what prompted it).
- [ ] Plan in a fresh session, writing spec.md; then run per run-spec.
  - Decide: displace a `qwen3.6-27b` entry or add to the fleet, quant and publisher, whether the build has
    to move, and whether to use its MTP head at all.
- [ ] Replace the Known lines below with what the model card and the GGUF header actually say.

Known, all of it UNVERIFIED (web summaries, not the model card): open weights under Apache-2.0 reported
2026-08-14, GGUFs from bartowski and ggml-org, ~20 GB at Q4_K_M so it partial-offloads on the 12 GB card,
and MTP shipped in-checkpoint. Nothing is downloaded or served, and the GPU gate was closed at scaffold time.
