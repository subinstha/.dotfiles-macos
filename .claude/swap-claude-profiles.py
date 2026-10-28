#!/usr/bin/env python3
"""One-off move of the Claude Code profiles, 2026-10-27.

Before: ~/.claude was personal and ~/.claude-work was work.
After:  ~/.claude is work and ~/.claude-personal is personal.

The desktop app only reads ~/.claude, so work has to live there. Work repos
(anything with ComplyPilot in its project folder name) stay in ~/.claude
together with their auto-memory, since those sessions are work. Everything
else in ~/.claude moves to ~/.claude-personal, and ~/.claude-work is merged
into ~/.claude. Plugins stay where they are; link-claude.sh points the
personal profile at them.

Nothing is deleted. Anything that would overwrite something goes to
~/claude-migration-backup-20261027 instead.

The keychain logins move too, so neither profile has to log in again:
"Claude Code-credentials" (the ~/.claude login, personal until now) is copied
to the ~/.claude-personal service, and the ~/.claude-work login is copied to
"Claude Code-credentials". macOS may ask to let `security` read them.

Quit every Claude Code session and the desktop app first; the script refuses
to run while either is up. Dry run by default, --apply to do it.
"""

import hashlib
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
WORK = HOME / ".claude"
OLD_WORK = HOME / ".claude-work"
PERSONAL = HOME / ".claude-personal"
BACKUP = HOME / "claude-migration-backup-20261027"
MARKER = PERSONAL / ".swapped-2026-10-27"
DOTFILES = HOME / ".dotfiles-macos" / ".claude"

# Symlinks into the dotfiles (or plugins, which stay in ~/.claude).
# link-claude.sh recreates the links in both profiles at the end.
LINKED = {"commands", "hooks", "skills", "settings.local.json", "plugins"}
# Per-session folders, keyed by session id, that follow their transcript.
PER_SESSION = {"file-history", "session-env", "tasks", "todos"}

APPLY = "--apply" in sys.argv
# Paths a dry run has "moved" already, so later steps see them as gone.
vacated: set[Path] = set()


def say(msg: str) -> None:
    print(("" if APPLY else "[dry run] ") + msg)


def is_work_project(name: str) -> bool:
    return "ComplyPilot" in name


def present(path: Path) -> bool:
    if any(p in vacated for p in (path, *path.parents)):
        return False
    return path.exists() or path.is_symlink()


def move(src: Path, dst: Path) -> None:
    """Move src to dst. An existing dst is kept and src goes to BACKUP."""
    vacated.add(src)
    if present(dst):
        if dst.is_dir() and not dst.is_symlink() and not any(dst.iterdir()):
            say(f"rmdir empty {dst}")
            if APPLY:
                dst.rmdir()
        elif dst.name == ".DS_Store":
            say(f"rm {dst}")
            if APPLY:
                dst.unlink()
        else:
            dst = BACKUP / "conflicts" / src.relative_to(HOME)
            say(f"conflict, backing up {src} -> {dst}")
    else:
        say(f"mv {src} -> {dst}")
    if APPLY:
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(src), str(dst))


def merge_dir(src: Path, dst: Path) -> None:
    """Move each entry of src into dst, recursing into folders both have."""
    for entry in sorted(src.iterdir()):
        target = dst / entry.name
        if entry.is_dir() and not entry.is_symlink() and present(target) and target.is_dir():
            merge_dir(entry, target)
        elif present(target) and entry.is_file() and target.is_file():
            merge_file(entry, target)
        else:
            move(entry, target)
    if APPLY and src.is_dir() and not any(src.iterdir()):
        src.rmdir()


def merge_file(src: Path, dst: Path) -> None:
    if src.read_bytes() == dst.read_bytes():
        say(f"identical, dropping {src}")
        if APPLY:
            src.unlink()
        return
    if dst.name == "MEMORY.md":
        # The index: keep the target's lines and add the source's entries for
        # files the target doesn't link yet.
        have = dst.read_text().splitlines()
        linked = set(re.findall(r"\]\(([^)]+)\)", "\n".join(have)))
        extra = [l for l in src.read_text().splitlines()
                 if l.strip() and l not in have
                 and not set(re.findall(r"\]\(([^)]+)\)", l)) & linked]
        say(f"merge {len(extra)} index lines from {src} into {dst}")
        if APPLY:
            dst.write_text("\n".join(have + extra) + "\n")
            src.unlink()
        return
    # Keep the newer copy in place, the older one in BACKUP.
    if src.stat().st_mtime > dst.stat().st_mtime:
        older = BACKUP / "conflicts" / dst.relative_to(HOME)
        say(f"{src} is newer: {dst} -> {older}, then {src} -> {dst}")
        if APPLY:
            older.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(dst), str(older))
            shutil.move(str(src), str(dst))
    else:
        move(src, dst)


def history_lines(path: Path) -> list[str]:
    return path.read_text().splitlines() if path.exists() else []


def split_history() -> list[str]:
    """Split ~/.claude/history.jsonl. Returns the work lines; personal lines
    go to ~/.claude-personal/history.jsonl."""
    work, personal = [], []
    for line in history_lines(WORK / "history.jsonl"):
        try:
            project = json.loads(line).get("project") or ""
        except json.JSONDecodeError:
            project = ""
        (work if is_work_project(project) else personal).append(line)
    say(f"history.jsonl: {len(work)} work lines stay, {len(personal)} to personal")
    if APPLY:
        (PERSONAL / "history.jsonl").write_text("".join(l + "\n" for l in personal))
    return work


def write_history(work_lines: list[str]) -> None:
    lines = work_lines + history_lines(OLD_WORK / "history.jsonl")

    def ts(line: str) -> float:
        try:
            return float(json.loads(line).get("timestamp") or 0)
        except (json.JSONDecodeError, TypeError, ValueError):
            return 0.0

    lines = sorted(dict.fromkeys(lines), key=ts)
    say(f"history.jsonl: {len(lines)} lines in {WORK / 'history.jsonl'}")
    vacated.add(OLD_WORK / "history.jsonl")
    if APPLY:
        (WORK / "history.jsonl").write_text("".join(l + "\n" for l in lines))
        (OLD_WORK / "history.jsonl").unlink(missing_ok=True)


def work_session_ids() -> set[str]:
    ids = set()
    for root in (WORK / "projects", OLD_WORK / "projects"):
        if not root.is_dir():
            continue
        for proj in root.iterdir():
            if proj.is_dir() and (root == OLD_WORK / "projects" or is_work_project(proj.name)):
                ids.update(f.stem for f in proj.glob("*.jsonl"))
    return ids


def keychain_service(config_dir: Path | None) -> str:
    base = "Claude Code-credentials"
    if config_dir is None:
        return base
    return f"{base}-{hashlib.sha256(str(config_dir).encode()).hexdigest()[:8]}"


def keychain_read(service: str) -> tuple[str, bytes] | None:
    attrs = subprocess.run(
        ["security", "find-generic-password", "-s", service],
        capture_output=True, text=True,
    )
    if attrs.returncode != 0:
        return None
    account = next(
        (l.split("=", 1)[1].strip().strip('"') for l in attrs.stdout.splitlines()
         if l.strip().startswith('"acct"')),
        "",
    )
    secret = subprocess.run(
        ["security", "find-generic-password", "-s", service, "-w"],
        capture_output=True,
    )
    if secret.returncode != 0:
        return None
    return account, secret.stdout.rstrip(b"\n")


def keychain_write(service: str, account: str, secret: bytes) -> bool:
    # Through `security -i` on stdin so the secret never shows up in ps.
    cmd = f'add-generic-password -U -a "{account}" -s "{service}" -X {secret.hex()}\n'
    return subprocess.run(["security", "-i"], input=cmd.encode()).returncode == 0


def swap_keychain() -> None:
    default = keychain_service(None)
    old_work = keychain_service(OLD_WORK)
    personal = keychain_service(PERSONAL)
    say(f"keychain: '{default}' -> '{personal}', '{old_work}' -> '{default}'")
    if not APPLY:
        return
    p, w = keychain_read(default), keychain_read(old_work)
    if p is None or w is None:
        print("keychain: could not read both logins. Run /login once in each profile.")
        return
    if keychain_write(personal, *p) and keychain_write(default, *w):
        print("keychain: logins moved.")
    else:
        print("keychain: write failed. Run /login once in each profile.")


def running() -> list[str]:
    found = []
    if subprocess.run(["pgrep", "-x", "claude"], capture_output=True).returncode == 0:
        found.append("Claude Code CLI sessions")
    if subprocess.run(["pgrep", "-f", "Claude.app/Contents/MacOS/Claude$"],
                      capture_output=True).returncode == 0:
        found.append("the Claude desktop app")
    return found


def main() -> None:
    if MARKER.exists():
        sys.exit(f"Already done ({MARKER} exists).")
    if not OLD_WORK.is_dir():
        sys.exit(f"{OLD_WORK} is missing, nothing to swap.")
    if APPLY and (up := running()):
        sys.exit(f"Quit {' and '.join(up)} first (⌘Q the app), then re-run.")

    ids = work_session_ids()
    say(f"{len(ids)} work sessions stay in {WORK}")
    if APPLY:
        PERSONAL.mkdir(exist_ok=True)

    # 1. Personal data out of ~/.claude.
    work_history = split_history()
    for entry in sorted(WORK.iterdir()):
        name = entry.name
        if name in LINKED or name == "history.jsonl":
            continue
        if name == ".claude.json":  # unused stray; the default profile reads ~/.claude.json
            move(entry, BACKUP / "stray-claude-dir-claude.json")
        elif name == "projects":
            for proj in sorted(entry.iterdir()):
                if not is_work_project(proj.name):
                    move(proj, PERSONAL / "projects" / proj.name)
        elif name in PER_SESSION and entry.is_dir():
            for item in sorted(entry.iterdir()):
                if item.name.split(".")[0] not in ids:
                    move(item, PERSONAL / name / item.name)
        else:
            move(entry, PERSONAL / name)
    move(HOME / ".claude.json", PERSONAL / ".claude.json")
    if present(HOME / ".claude.json.backup"):
        move(HOME / ".claude.json.backup", BACKUP / "claude.json.backup-personal")

    # 2. ~/.claude-work into ~/.claude.
    write_history(work_history)
    move(OLD_WORK / ".claude.json", HOME / ".claude.json")
    for entry in sorted(OLD_WORK.iterdir()):
        if entry in vacated:
            continue
        if entry.name in LINKED and entry.is_symlink():
            say(f"rm link {entry}")
            if APPLY:
                entry.unlink()
        elif entry.is_dir() and present(WORK / entry.name) and (WORK / entry.name).is_dir():
            merge_dir(entry, WORK / entry.name)
        else:
            move(entry, WORK / entry.name)
    if APPLY:
        if any(OLD_WORK.iterdir()):
            move(OLD_WORK, BACKUP / "claude-work-leftovers")
        else:
            OLD_WORK.rmdir()

    # 3. Logins, the desktop app's env, links.
    swap_keychain()
    say("launchctl unsetenv CLAUDE_CONFIG_DIR")
    plist = HOME / "Library/LaunchAgents/local.claude-config-dir.plist"
    if APPLY:
        subprocess.run(["launchctl", "unsetenv", "CLAUDE_CONFIG_DIR"])
        if plist.exists():
            subprocess.run(["launchctl", "unload", str(plist)])
            move(plist, BACKUP / plist.name)
    say(f"run {DOTFILES / 'link-claude.sh'}")
    if APPLY:
        subprocess.run(["sh", str(DOTFILES / "link-claude.sh")], check=True)
        MARKER.write_text("~/.claude is work, ~/.claude-personal is personal.\n")
        print("Done. Open a new terminal so the shell picks up the new aliases.")
    else:
        print("\nNothing changed. Re-run with --apply once every Claude session and the app are closed.")


if __name__ == "__main__":
    main()
