# 2026-09-20: Ollama store purge

Closes Phase 4 of `specs/done/llamacpp-migration`: the retired on-disk Ollama install is gone.
The user ran every command (sudo needs a password on this box); this session captured and verified the state.

- Validation window: opened 2026-08-07 at the stop+disable, ran ~6 weeks, and no rollback was ever taken.
  - The spec's eligibility date was ~2026-08-21, so the purge ran 30 days after it, not on it.
- No GPU or CPU inference ran. `ollama serve` loads on request only, and the purge sends none.

## Disk

| Point | `/` used | `/` available |
|---|---|---|
| Before | 506G | 451G |
| After | 320G | 637G |

- **186G reclaimed guest-side**, against a pre-purge `sudo du -sh /usr/share/ollama` of 187G.
- `/mnt/f` is unchanged at 231G available, as expected: the store sat on the guest root, not on F:.
- The repo carried two conflicting figures beforehand - 232G in `specs/done/llamacpp-migration/spec.md:45` and 186G
  in the 2026-08-07 architecture.md rewrite. The 187G measured here matches the latter.
- Host-side reclaim is NOT done: `wsl --shutdown` + `Optimize-VHD` still has to run, or the vhdx keeps the
  space from Windows. The guest sees it back either way.

### Follow-up: host-side reclaim, same day

- User ran `wsl --shutdown` + `Optimize-VHD` in Windows.
- Verified via `df -h /mnt/f`: 231G -> 417G available, a 186G gain matching the "186G reclaimed guest-side"
  figure above exactly (that section's other number, 187G, is a separate pre-purge `du` estimate, not this delta).
- Closes the bundle's last open item (`specs/done/llamacpp-migration/tasks.md`).

## What ran

- `ollama rm` removed all 23 models, matching the 23 names of the 2026-08-03 parity check (tasks.md:101).
  - Kept as specified rather than skipped, on the user's call, though the store was deleted wholesale next.
- Deleted: `/usr/share/ollama`, `/usr/local/bin/ollama`, `ollama.service`, and its `.d/override.conf`.
- `userdel` printed `group ollama not removed because it has other members`, but the state says otherwise:
  `getent passwd ollama` and `getent group ollama` both return nothing, and `id wma` shows no ollama group.
  - So the warning was transient. Both the user and the group are gone.

## Verified after

- Store, binary, unit and override: all absent.
- `systemctl status ollama` reports `Unit ollama.service could not be found`.
- Ports 11433 and 11434 both closed (the router was not running at the time).
- The world-readable `OLLAMA_API_KEY` copy in `override.conf` went with it. Before deleting, this session
  confirmed `~/.config/claude-local.env` (mode 600) holds a byte-identical copy, so the web-search MCP
  keeps working. That key sat world-readable from 2026-07-03 to today; rotating it is the user's call.
