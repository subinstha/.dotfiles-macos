#!/usr/bin/env python3
"""Classify every git worktree of the current repo as remove / ask / keep.

Read-only: runs `git fetch --prune` (unless --no-fetch) and reads state, never removes anything.

  remove  not in use, no open PR, clean tree, no commits missing from the remote
          (PR merged/closed, or no PR and nothing unique on it)
  ask     not in use, no open PR, but removing would lose work
          (uncommitted changes or commits not on any remote branch)
  keep    in use by a session/process, has an open PR, or is the main/current worktree

Usage: scan.py [--no-fetch] [--active-minutes N] [--json]
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path


def run(cmd, cwd=None, check=False):
    p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if check and p.returncode != 0:
        sys.exit(f"{' '.join(cmd)} failed: {p.stderr.strip()}")
    return p


def list_worktrees():
    out = run(["git", "worktree", "list", "--porcelain"], check=True).stdout
    trees, cur = [], {}
    for line in out.splitlines() + [""]:
        if not line:
            if cur:
                trees.append(cur)
            cur = {}
            continue
        key, _, val = line.partition(" ")
        if key == "worktree":
            cur["path"] = val
        elif key == "branch":
            cur["branch"] = val.removeprefix("refs/heads/")
        elif key in ("detached", "bare"):
            cur[key] = True
        elif key in ("locked", "prunable"):
            cur[key] = val or True
    return trees


def process_cwds():
    """Map of cwd -> list of 'comm(pid)' for every process the user can see."""
    out = run(["lsof", "-a", "-d", "cwd", "-Fpcn"]).stdout
    cwds, pid, comm = {}, None, None
    for line in out.splitlines():
        tag, val = line[:1], line[1:]
        if tag == "p":
            pid = val
        elif tag == "c":
            comm = val
        elif tag == "n":
            cwds.setdefault(os.path.realpath(val), []).append(f"{comm}({pid})")
    return cwds


def pid_alive(pid):
    try:
        os.kill(int(pid), 0)
        return True
    except PermissionError:
        return True
    except (OSError, ValueError):
        return False


def encode(path):
    """Claude Code's directory name for a cwd (~/.claude/projects/<enc>, /tmp/claude-<uid>/<enc>)."""
    return re.sub(r"[^A-Za-z0-9]", "-", path)


def claude_transcript_age_minutes(path):
    """Minutes since a Claude Code transcript for this cwd was last written, or None.

    Checks both profiles, ~/.claude (work) and ~/.claude-personal, plus
    ~/.claude-work, which held the work profile until 2026-10-27."""
    mtimes = []
    for profile in (".claude", ".claude-personal", ".claude-work"):
        proj = Path.home() / profile / "projects" / encode(path)
        if proj.is_dir():
            mtimes += [f.stat().st_mtime for f in proj.glob("*.jsonl")]
    return (time.time() - max(mtimes)) / 60 if mtimes else None


def fetch_prs():
    p = run(["gh", "pr", "list", "--state", "all", "--limit", "1000",
             "--json", "number,headRefName,state,url,updatedAt"])
    if p.returncode != 0:
        sys.exit(f"gh pr list failed (is gh authenticated for this repo?): {p.stderr.strip()}")
    by_branch = {}
    for pr in json.loads(p.stdout):
        by_branch.setdefault(pr["headRefName"], []).append(pr)
    return by_branch


def pick_pr(prs):
    """Open PR wins; otherwise the most recently updated one."""
    if not prs:
        return None
    open_prs = [p for p in prs if p["state"] == "OPEN"]
    return open_prs[0] if open_prs else max(prs, key=lambda p: p["updatedAt"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-fetch", action="store_true")
    ap.add_argument("--active-minutes", type=int, default=120,
                    help="a Claude transcript written within this many minutes counts as in use")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    if not args.no_fetch:
        run(["git", "fetch", "--prune", "--quiet"])

    here = os.path.realpath(run(["git", "rev-parse", "--show-toplevel"], check=True).stdout.strip())
    trees = list_worktrees()
    main_path = os.path.realpath(trees[0]["path"])
    cwds = process_cwds()
    prs = fetch_prs()
    owners_by_enc = {encode(os.path.realpath(t["path"])): os.path.realpath(t["path"]) for t in trees}

    results = []
    for t in trees:
        path = t["path"]
        real = os.path.realpath(path)
        r = {"path": path, "branch": t.get("branch"), "pr": None, "reasons": [],
             "locked": bool(t.get("locked")), "stale_lock": False}

        def keep(reason):
            r["verdict"] = "keep"
            r["reasons"].append(reason)

        if real == main_path:
            keep("main worktree")
            results.append(r)
            continue
        if real == here:
            keep("current worktree (this session)")
            results.append(r)
            continue
        if t.get("prunable") or not os.path.isdir(path):
            r["verdict"] = "remove"
            r["reasons"].append("directory is gone (prunable)")
            results.append(r)
            continue

        # In use: a live process sits inside the worktree
        users = [u for cwd, us in cwds.items()
                 if cwd == real or cwd.startswith(real + os.sep) for u in us]
        if users:
            keep("process inside: " + ", ".join(sorted(set(users))[:5]))

        # In use: lives in the scratchpad of a Claude session whose own worktree is busy
        m = re.search(r"/claude-\d+/([^/]+)/[0-9a-f-]{36}/scratchpad/", real)
        if m:
            owner = owners_by_enc.get(m.group(1))
            if owner and any(c == owner or c.startswith(owner + os.sep) for c in cwds):
                keep(f"in scratchpad of live session at {owner}")

        # In use: Claude Code lock whose owning pid is still alive
        lock = t.get("locked")
        if isinstance(lock, str):
            m = re.search(r"\bpid (\d+)", lock)
            if m and pid_alive(m.group(1)):
                keep(f"locked by live pid {m.group(1)}")
            elif m:
                r["stale_lock"] = True
            else:
                keep(f"locked: {lock}")
        elif lock:
            keep("locked (no reason given)")

        # In use: a Claude transcript for this cwd was written recently
        age = claude_transcript_age_minutes(real)
        if age is not None and age < args.active_minutes:
            keep(f"Claude transcript written {age:.0f} min ago")

        # PR state
        pr = pick_pr(prs.get(t.get("branch") or "", []))
        if pr:
            r["pr"] = {"number": pr["number"], "state": pr["state"], "url": pr["url"]}
            if pr["state"] == "OPEN":
                keep(f"open PR #{pr['number']}")

        # Unique work that removal would lose
        dirty = run(["git", "-C", path, "status", "--porcelain"]).stdout.strip()
        n_dirty = len(dirty.splitlines()) if dirty else 0
        unpushed = run(["git", "-C", path, "rev-list", "--count", "HEAD", "--not", "--remotes"]).stdout.strip()
        n_unpushed = int(unpushed) if unpushed.isdigit() else 0
        r["dirty_files"], r["unpushed_commits"] = n_dirty, n_unpushed

        if r.get("verdict") == "keep":
            results.append(r)
            continue

        r["reasons"].append(f"PR #{pr['number']} {pr['state'].lower()}" if pr else "no PR")
        if n_dirty or n_unpushed:
            r["verdict"] = "ask"
            if n_dirty:
                r["reasons"].append(f"{n_dirty} uncommitted file(s)")
            if n_unpushed:
                r["reasons"].append(f"{n_unpushed} commit(s) not on any remote branch")
        else:
            r["verdict"] = "remove"
        if r["stale_lock"]:
            r["reasons"].append("stale lock (owner pid dead)")
        results.append(r)

    if args.json:
        print(json.dumps(results, indent=2))
        return
    for verdict in ("remove", "ask", "keep"):
        group = [r for r in results if r["verdict"] == verdict]
        print(f"\n== {verdict.upper()} ({len(group)})")
        for r in group:
            print(f"  {r['path']}\n      [{r['branch'] or 'detached'}] {'; '.join(r['reasons'])}")


if __name__ == "__main__":
    main()
