#!/usr/bin/env bash
# PreToolUse Bash guard: refuse commands that would print AWS credentials or
# secret-store values into the transcript (which leaves this machine and is
# stored in plaintext session logs).
#
# Installed by request after a real credential leak. The companion prose policy
# is ~/.codex/AGENTS.md (global, for Codex) and the "Credential handling"
# section of ComplyPilot's CLAUDE.md (this repo, for both agents).
#
# Always exits 0. A refusal is expressed as a PreToolUse permissionDecision of
# "deny" so the model is told why, rather than the hook erroring.
#
# Two deliberate limits:
#   - Heredoc bodies are stripped before matching, so writing documentation
#     that NAMES these commands is allowed. Only running them is blocked.
#   - Patterns are anchored to command positions, so a forbidden string inside
#     a quoted argument (echo, printf) does not trip the guard.
# This is a guardrail against accident, not a sandbox: an `eval` of an
# assembled string can still get through. Real containment is that no static
# keys exist on disk and that SSO tokens expire.
set -uo pipefail

exec python3 -c '
import json, re, sys

try:
    cmd = (json.load(sys.stdin).get("tool_input") or {}).get("command") or ""
except Exception:
    sys.exit(0)
if not cmd:
    sys.exit(0)


def strip_heredocs(text):
    """Drop heredoc bodies: their content is data being written, not commands."""
    out, lines, i = [], text.split("\n"), 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        m = re.search(r"<<(-?)\s*([\x27\"]?)([A-Za-z_][A-Za-z0-9_]*)\2", line)
        if m:
            delim, dash = m.group(3), m.group(1) == "-"
            i += 1
            while i < len(lines):
                probe = lines[i].strip() if dash else lines[i]
                if probe == delim:
                    break
                i += 1
        i += 1
    return "\n".join(out)


scan = strip_heredocs(cmd)

# A command position: start, or after a separator, optionally via sudo/env.
AT = r"(?:^|[\n;&|(`]|&&|\|\|)\s*(?:sudo\s+)?(?:env\s+[A-Za-z_][A-Za-z0-9_]*=\S*\s+)*"

RULES = [
    (AT + r"aws\s+configure\s+export-credentials",
     "Blocked: that command emits the secret key and session token, which would then live in this session transcript and its log files. Use \x27aws sts get-caller-identity\x27 to confirm auth, or let the CLI read its own cache."),
    (AT + r"aws\s+sts\s+(?:get-session-token|get-federation-token|assume-role)",
     "Blocked: that \x27aws sts\x27 subcommand returns a secret key and session token in plaintext. If a role must be assumed, add a named profile with role_arn to ~/.aws/config so the CLI holds the credentials itself."),
    (AT + r"aws\s+sso\s+get-role-credentials",
     "Blocked: that command prints role credentials and requires passing the raw SSO access token. Use \x27aws sso login --profile <name>\x27 and let CLI v2 own the token."),
    (AT + r"aws\s+iam\s+create-access-key",
     "Blocked: that would mint a long-lived static key, the credential class behind the previous leak. This account uses IAM Identity Center SSO; no static keys should exist."),
    (AT + r"aws\s+secretsmanager\s+get-secret-value",
     "Blocked: that would print the secret into this transcript. Use \x27describe-secret\x27 to prove it exists, or ask the user to read the value themselves with a \x27! aws ...\x27 command."),
    (AT + r"aws\s+ssm\s+get-parameters?\b[^\n;&|]*--with-decryption",
     "Blocked: \x27--with-decryption\x27 would print a SecureString value into this transcript. Fetch it without decryption to confirm it exists, or ask the user to read it themselves."),
]

SECRET_PATH = r"\.aws/(?:credentials|sso/cache|cli/cache)"
READERS = (
    "cat|bat|less|more|head|tail|strings|xxd|od|base64|cp|mv|tee|jq|yq|"
    "python3?|node|perl|ruby|awk|sed|grep|rg|ugrep|curl|wget|open|pbcopy|"
    "scp|rsync|zip|tar|gzip|dd|sqlite3|code|vim|nano"
)
PATH_REASON = (
    "Blocked: that would read AWS credential material (~/.aws/credentials, the "
    "SSO token cache, or the CLI credential cache) into this transcript. "
    "\x27aws sts get-caller-identity\x27 reports whether credentials work without "
    "exposing them, and \x27ls\x27/\x27stat\x27 on those paths is allowed if you only "
    "need to know they exist. ~/.aws/config holds no secrets and is fine to read."
)

ENV_RULES = [
    (r"(?:echo|printf|printenv|print)[^|;&\n]*AWS_(?:SECRET_ACCESS_KEY|SESSION_TOKEN)",
     "Blocked: that would print AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN into this transcript. To check only whether they are set, print the variable NAMES: env | cut -d= -f1 | grep ^AWS"),
    (r"grep[^|;&\n]*AWS_(?:SECRET_ACCESS_KEY|SESSION_TOKEN)",
     "Blocked: grepping for AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN values would copy them into this transcript. Print variable names instead: env | cut -d= -f1 | grep ^AWS"),
]


def deny(reason):
    json.dump({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }, sys.stdout)
    sys.exit(0)


for pat, reason in RULES:
    if re.search(pat, scan, re.I):
        deny(reason)

def split_segments(text):
    """Split on shell separators, ignoring those inside quotes, so that a
    `python3 -c "a;b"` stays one segment while `ls x; cat y` becomes two."""
    segs, buf, quote = [], [], None
    for ch in text:
        if quote:
            if ch == quote:
                quote = None
            buf.append(ch)
        elif ch in "\x27\"":
            quote = ch
            buf.append(ch)
        elif ch in "\n;|&":
            segs.append("".join(buf))
            buf = []
        else:
            buf.append(ch)
    segs.append("".join(buf))
    return segs


# Pair the reader with the path inside the SAME command segment, so that a
# reader in one segment does not condemn a mere `ls` of the path in another.
for seg in split_segments(scan):
    if re.search(SECRET_PATH, seg, re.I) and re.search(
        r"^\s*(?:sudo\s+)?(?:env\s+[A-Za-z_][A-Za-z0-9_]*=\S*\s+)*(?:"
        + READERS + r")(?![A-Za-z0-9_-])",
        seg,
        re.I,
    ):
        deny(PATH_REASON)

for pat, reason in ENV_RULES:
    if re.search(pat, scan):
        deny(reason)

sys.exit(0)
'
