# tmux agent sessions: Claude Code / Codex that survive a reboot

Last reviewed: 6 October 2026
Status: in use on `devserver`; installer tested in sandbox homes only, **not yet on a second machine** and
the reboot restore itself is not yet proven end to end (see Testing).

## Problem

We run many long-lived Claude Code and Codex sessions, one per named tmux session. After a reboot,
tmux-resurrect + tmux-continuum bring back the *windows, panes and folders*, but a relaunched agent is a
brand-new conversation. The messages are not lost: both tools keep their transcripts on disk. The job is to
reopen the right one in the right pane.

## How it works

| Piece | What it does |
|---|---|
| `claude-tmux` | Gives each tmux session ONE stable Claude conversation id (stored in `~/.local/share/claude-tmux/<tmux-session>`). First run: `claude --session-id <id> --name <session>`. Later runs: `claude --resume <id>`. |
| `codex-tmux` | Same idea for Codex. Codex cannot be given an id or a name at launch, so a short-lived watcher learns the new session's id from the rollout file Codex creates, and stores it (`~/.local/share/codex-tmux/<tmux-session>`). Later runs: `codex resume <id>`. |
| `agent-adopt` | Ties agents that are *already running* (started with plain `claude` / `codex`) to their tmux session, so the next restore reopens them. Read-only by default. |
| tmux config | `@resurrect-processes '"~claude->claude-tmux" "~codex->codex-tmux"'`: any pane that was running something containing `claude` / `codex` is restored by running the launcher. `@continuum-restore on` restores at tmux start; optional `@continuum-boot on` starts tmux at boot. |

Why a stable id per tmux session and not `claude --continue` / `codex resume --last`: those pick "the most
recent conversation in this folder". Several tmux sessions share a folder (on devserver: 5 Codex panes in
`labit-main`), so they would all reopen the same conversation.

## Install (new machine)

```bash
git clone git@github.com:labbit-23/sdrc-infrastructure.git && cd sdrc-infrastructure/scripts/agent-tmux
./install.sh --dry-run          # see what it would do
./install.sh --boot             # launchers + tmux plugins + config; --boot also starts tmux at boot
tmux source-file ~/.tmux.conf   # or start a fresh tmux
```

Requires tmux, python3, git, and `~/.local/bin` (or `--prefix`) on PATH. Claude Code / Codex themselves are
installed separately. The installer is idempotent: it owns one marked block in `~/.tmux.conf`, places it
before the `run ... tpm` line, and skips any setting you already configured by hand.

## Daily use

- Start agents with `claude-tmux` / `codex-tmux` instead of `claude` / `codex`. Extra arguments are passed through.
- Started a new conversation inside the tool (`/clear`, `/new`)? Run `claude-tmux --new` / `codex-tmux --new`
  next time so the saved id follows the new conversation. Otherwise a restore reopens the old one.
- Agents already running: `agent-adopt` (list), then `agent-adopt --apply`. Panes that share a folder are
  listed **AMBIGUOUS** and skipped: map those by hand, `echo <session-id> > ~/.local/share/<tool>-tmux/<tmux-session>`
  (Claude id = the `.jsonl` filename in `~/.claude/projects/<folder>/`; Codex id = the uuid at the end of the
  rollout filename in `~/.codex/sessions/YYYY/MM/DD/`).

## What survives and what does not

Survives: the whole message history, `CLAUDE.md`, saved memory, every file on disk including uncommitted edits.
Lost: background commands that were still running, a tool call that was mid-flight, per-session permission
approvals. Resumed Claude conversations may be summarised on the way back in.

## Gotchas found while building this (do not rediscover)

1. **Never name a launcher `cc`.** `/usr/bin/cc` is the C compiler and `~/.local/bin` precedes it on PATH, so it
   silently breaks native builds. Hence `claude-tmux`, not `cc`.
2. **`tmux display-message -p '#S'` is not enough.** Without `-t "$TMUX_PANE"` tmux answers with the most
   recently active client's session, so every pane would get the same name and the same conversation. The
   launchers use `-t "$TMUX_PANE"`; there is a regression test in the Testing section.
3. **`systemctl --user stop tmux.service` kills every tmux session.** `@continuum-boot on` creates that unit
   (`ExecStart=tmux new-session -d`, `ExecStop=save.sh; tmux kill-server`). It is meant to run at boot and
   shutdown only. Do not stop it on a live machine. While it is inactive there is no final save at shutdown;
   the 10-minute timer saves are what you get.
4. **Put the settings above the `run tpm` line.** `@continuum-boot` is read when the plugin loads.
5. **`agent-adopt` guesses** ("newest transcript in that folder"). It only auto-writes where exactly one pane of
   that tool uses the folder. A stale pane can still map to a more recently used conversation; check the
   "modified N min ago" column before `--apply`.
6. **Codex has thread names too.** `codex resume` accepts a session id or a thread name, names live in
   `~/.codex/session_index.jsonl`, and the TUI has a Rename-thread dialog. We use ids because a name cannot be
   set at launch and how Codex resolves two threads with the same name is unverified.
7. Claude `--resume <id>` is, to our knowledge, scoped to the project folder the conversation started in. If a
   pane restores into a different folder it may not find the transcript. Verify on your tmux-resurrect version.

## Testing

Syntax/behaviour of the launchers was checked with stand-in binaries (`CLAUDE_BIN=echo`, a fake `codex` that
writes a rollout file) in a throwaway `$HOME`, including: stable id across runs, resume once a transcript
exists, `--new`, two real tmux sessions getting different ids, Codex ignoring an older unrelated session.
To repeat, set `CLAUDE_BIN` / `CODEX_BIN`, `CLAUDE_TMUX_DIR` / `CODEX_TMUX_DIR`, `CODEX_SESSIONS_DIR` and a
temporary `HOME`; nothing real is touched.

**Not yet proven: a real restore.** Suggested first proof, on a spare machine or at a quiet time: start
`claude-tmux` in a throwaway tmux session, send one message, run
`~/.tmux/plugins/tmux-resurrect/scripts/save.sh`, kill only that session, run
`~/.tmux/plugins/tmux-resurrect/scripts/restore.sh`, and confirm the pane reopens the same conversation. Then
a real reboot with `--boot`. Record the result here.

## Files and state

- Repo: `scripts/agent-tmux/` (`claude-tmux`, `codex-tmux`, `agent-adopt`, `install.sh`).
- Installed to `~/.local/bin/`. Per-session ids in `~/.local/share/{claude,codex}-tmux/`.
- tmux snapshots: `~/.local/share/tmux/resurrect/` (`last` symlink), every 10 minutes.
- Revert: delete the marked block in `~/.tmux.conf`, remove the launchers; mapping files are harmless.
