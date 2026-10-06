# agent-tmux

Claude Code / Codex sessions that survive a reboot, one conversation per named tmux session.
Full explanation, install steps, gotchas and testing: [`runbooks/tmux-agent-sessions.md`](../../runbooks/tmux-agent-sessions.md).

```bash
./install.sh --dry-run && ./install.sh --boot    # then: tmux source-file ~/.tmux.conf
agent-adopt                                      # adopt already-running agents (read-only; --apply to write)
```

Files: `claude-tmux`, `codex-tmux` (launchers), `agent-adopt`, `install.sh`.
