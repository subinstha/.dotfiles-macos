#!/usr/bin/env python3
"""Summarize a Codex session so Claude can pick it up.

Usage: codex_session.py <session-id | codex://threads/<id> | --last> [--out DIR]

Prints a summary to stdout and writes the full condensed transcript to
<out>/codex-<id>.md (default: $TMPDIR). Reads ~/.codex only; never writes there.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

CODEX = Path.home() / ".codex"
ROOTS = [CODEX / "sessions", CODEX / "archived_sessions"]
ID_RE = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", re.I)


def find_transcript(arg):
    files = [p for r in ROOTS if r.exists() for p in r.rglob("rollout-*.jsonl*")]
    if arg == "--last":
        if not files:
            sys.exit("No Codex transcripts found under ~/.codex")
        return max(files, key=lambda p: p.stat().st_mtime)
    m = ID_RE.search(arg)
    sid = (m.group(0) if m else arg.rsplit("/", 1)[-1]).lower()
    hits = [p for p in files if sid in p.name.lower()]
    if not hits:
        sys.exit(f"No Codex transcript matches '{sid}' under ~/.codex/sessions or archived_sessions")
    return max(hits, key=lambda p: p.stat().st_mtime)


def read_lines(path):
    if path.name.endswith(".zst"):
        out = subprocess.run(["zstd", "-dc", str(path)], capture_output=True, check=True).stdout
        text = out.decode("utf-8", "replace")
    else:
        text = path.read_text("utf-8", "replace")
    for line in text.splitlines():
        try:
            yield json.loads(line)
        except json.JSONDecodeError:
            continue


def content_text(content):
    if isinstance(content, str):
        return content
    parts = []
    for c in content or []:
        if isinstance(c, dict):
            parts.append(c.get("text") or c.get("input_text") or c.get("output_text") or "")
    return "\n".join(p for p in parts if p)


INJECTED = ("<recommended_plugins", "# AGENTS.md", "<environment_context", "<in-app-browser-context",
            "<user_instructions", "<permissions", "<skill", "<turn_aborted")


def user_text(content):
    """User message text with Codex-injected context blocks dropped."""
    if isinstance(content, str):
        content = [{"text": content}]
    keep = [c.get("text") or "" for c in content or [] if isinstance(c, dict)]
    return "\n".join(t for t in keep if t.strip() and not t.lstrip().startswith(INJECTED))


def clip(s, n):
    s = s or ""
    return s if len(s) <= n else s[:n] + f"\n…[{len(s) - n} more chars]"


def git(path, *args):
    r = subprocess.run(["git", "-C", str(path), *args], capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("session", nargs="?")
    ap.add_argument("--last", action="store_true", help="use the most recently written transcript")
    ap.add_argument("--out", default=os.environ.get("TMPDIR", tempfile.gettempdir()))
    a = ap.parse_args()

    if not a.session and not a.last:
        ap.error("give a session id, a codex://threads/<id> link, or --last")
    path = find_transcript("--last" if a.last else a.session)
    meta, cwds, worktrees, prs = {}, [], [], []
    user_msgs, completions, events = [], [], []
    last_started = last_completed = None

    for i, d in enumerate(read_lines(path)):
        t, p = d.get("type"), d.get("payload") or {}
        ts = d.get("timestamp", "")
        raw = json.dumps(p) if isinstance(p, dict) else ""
        for w in re.findall(r'worktree(?:GitRoot|WorkspaceRoot)\\*"\s*:\s*\\*"([^"\\]+)', raw):
            if w not in worktrees:
                worktrees.append(w)
        for pr in re.findall(r"https://github\.com/[\w.-]+/[\w.-]+/pull/\d+", raw):
            if pr not in prs:
                prs.append(pr)

        if t == "session_meta":
            meta = {k: v for k, v in p.items() if k not in ("base_instructions", "creator_user_id", "creator_account_id")}
        elif t == "turn_context" and p.get("cwd"):
            if not cwds or cwds[-1] != p["cwd"]:
                cwds.append(p["cwd"])
        elif t == "event_msg" and p.get("type") == "task_started":
            last_started = i
        elif t == "event_msg" and p.get("type") == "task_complete":
            last_completed = i
            completions.append((ts, p.get("last_agent_message"), (p.get("error") or {})))
            err = (p.get("error") or {})
            events.append(f"### [{ts}] TURN END" + (f" — ERROR {err.get('codex_error_info')}: {err.get('message')}" if err else ""))
        elif t == "response_item":
            pt = p.get("type")
            if pt == "message":
                role = p.get("role")
                text = user_text(p.get("content")) if role == "user" else content_text(p.get("content"))
                if role == "user" and text:
                    user_msgs.append((ts, text))
                    events.append(f"## [{ts}] USER\n{clip(text, 6000)}")
                elif role == "assistant":
                    events.append(f"## [{ts}] CODEX\n{clip(text, 4000)}")
            elif pt in ("function_call", "custom_tool_call"):
                args = p.get("arguments") or p.get("input") or ""
                events.append(f"- [{ts}] TOOL {p.get('namespace', '')}{p.get('name')}: {clip(str(args), 600)}")
            elif pt in ("function_call_output", "custom_tool_call_output"):
                out = p.get("output")
                out = content_text(out) if isinstance(out, list) else str(out)
                events.append(f"  → {clip(out, 400)}")
            elif pt == "agent_message":
                events.append(f"## [{ts}] CODEX (agent_message)\n{clip(content_text(p.get('content')) or raw, 3000)}")

    sid = meta.get("id") or meta.get("session_id") or path.name
    out = Path(a.out) / f"codex-{sid}.md"
    out.write_text("\n\n".join(events), "utf-8")

    age_min = (time.time() - path.stat().st_mtime) / 60
    running = last_started is not None and (last_completed is None or last_started > last_completed)

    print(f"Transcript:  {path}")
    print(f"Condensed:   {out}  ({len(events)} entries)")
    print(f"Session id:  {sid}")
    print(f"Started:     {meta.get('timestamp')}  originator={meta.get('originator')}  cli={meta.get('cli_version')}")
    g = meta.get("git") or {}
    print(f"Launch git:  branch={g.get('branch')} commit={g.get('commit_hash')} repo={g.get('repository_url')}")
    print(f"Last write:  {age_min:.0f} min ago" + ("  ⚠ a turn is still open — Codex may still be running" if running else ""))
    print(f"Launch cwd:  {meta.get('cwd')}")
    print(f"Turn cwds:   {cwds}")
    print(f"PR links:    {prs or 'none'}")

    print("\n== Worktree candidates ==")
    cands = []
    for c in worktrees + cwds[::-1] + [meta.get("cwd")]:
        if c and c not in cands:
            cands.append(c)
    for c in cands:
        if not Path(c).exists():
            print(f"- {c}  (missing)")
            continue
        top = git(c, "rev-parse", "--show-toplevel")
        if not top:
            print(f"- {c}  (exists, not a git checkout)")
            continue
        branch = git(top, "symbolic-ref", "--short", "-q", "HEAD") or "(detached)"
        head = git(top, "rev-parse", "--short", "HEAD")
        status = git(top, "status", "--short")
        n = len(status.splitlines()) if status else 0
        kind = "codex-managed" if "/.codex/worktrees/" in top else ("linked worktree" if git(top, "rev-parse", "--git-dir") != git(top, "rev-parse", "--git-common-dir") else "main checkout")
        print(f"- {top}  [{kind}] branch={branch} HEAD={head} changed_files={n}")
        if status:
            print("    " + "\n    ".join(status.splitlines()[:30]))

    print("\n== User requests (oldest first) ==")
    for ts, text in user_msgs:
        print(f"[{ts}] {clip(text.strip(), 1500)}\n")

    print("== How each turn ended ==")
    for ts, msg, err in completions[-6:]:
        if err:
            print(f"[{ts}] ERROR {err.get('codex_error_info')}: {clip(err.get('message'), 200)}")
        else:
            print(f"[{ts}] {clip((msg or '').strip(), 1200)}\n")


if __name__ == "__main__":
    main()
