# Tasks: Open WebUI wrap-up

Status legend: [ ] pending, [x] done. Resume point for this side task.

## In-browser pass

- [ ] Launch `~/.local/bin/openwebui`; login with recovered admin account.
- [ ] Chat against a migrated model (streams, sampling sane).
- [ ] Web search round-trip via Brave in a real chat.
- [ ] Native tool calling with `qwen3.6-27b-coding`.
- [ ] Vision: image drop on `gemma4-12b-it-qat` (mmproj kept the capability).
- [ ] Any failure written up in docs/openwebui.md or a history log.

## Chat-template gate

- [ ] `qwen3.5-queen-27b-coding-q4-k-m`: multi-system-message probe; record verdict.
- [ ] `gemma4-31b-it-heretic-i1-q4-k-m`: multi-system-message probe; record verdict.
- [ ] Verdicts recorded in README catalog or docs/openwebui.md.

## Model visibility

- [ ] Decide the user-facing default model set.
- [ ] Set it in Admin UI (Admin Panel > Settings > Models); record the intended set.

## Host-side disk reclaim (user)

- [ ] Delete orphaned blobs from `.migration-artifacts/orphans.txt` (needs sudo: stop ollama, delete, restart).
- [ ] Windows: `wsl --shutdown` then `Optimize-VHD` on the ext4.vhdx (~190 GB reclaim on F:).
