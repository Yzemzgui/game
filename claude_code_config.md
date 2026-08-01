# Claude Code setup — terse output + commit hook

Target: Windows, one repo first. All paths assume `%USERPROFILE%\.claude\` for user
scope and `<repo>\.claude\` for project scope.

---

## 1. settings.json

### Current

```json
{
  "includeCoAuthoredBy": false,
  "effortLevel": "high",
  "skipDangerousModePermissionPrompt": true,
  "theme": "dark",
  "defaultMode": "acceptEdits",
  "model": "sonnet"
}
```

### Changes

| Key | Action | Why |
|---|---|---|
| `includeCoAuthoredBy: false` | keep | already what you want |
| `theme: dark` | keep | cosmetic |
| `defaultMode: acceptEdits` | keep | edits auto-accepted, Bash still gated. Good balance |
| `model: sonnet` | keep as default | switch to Opus with `/model` for planning and review turns |
| `effortLevel: high` | consider `medium` | you asked for speed; high adds latency on every turn. Try medium for a week |
| `skipDangerousModePermissionPrompt: true` | **remove** | see below |
| `outputStyle` | **add** | activates the style in section 2 |
| `permissions.allow` | **add** | this is what actually reduces prompts |

**On `skipDangerousModePermissionPrompt`:** this only suppresses the confirmation
banner for bypass mode — it does not itself disable permission checks. But on a
machine holding cluster credentials, Artifactory tokens and the front-office
monorepo, you want that banner. The real fix for prompt fatigue is a narrow
allowlist of read-only commands (below), not removing the warning.

### Target

```json
{
  "includeCoAuthoredBy": false,
  "effortLevel": "medium",
  "theme": "dark",
  "defaultMode": "acceptEdits",
  "model": "sonnet",
  "outputStyle": "terse-eng",
  "permissions": {
    "allow": [
      "Bash(git status:*)",
      "Bash(git diff:*)",
      "Bash(git log:*)",
      "Bash(kubectl get:*)",
      "Bash(kubectl describe:*)",
      "Bash(kubectl logs:*)",
      "Bash(helm template:*)",
      "Bash(helm show:*)",
      "Bash(curl -sn https://<artifactory-host>/artifactory/api/*)"
    ],
    "deny": [
      "Bash(kubectl delete:*)",
      "Bash(helm uninstall:*)",
      "Bash(git push --force:*)",
      "Read(./.env)",
      "Read(./**/*.pem)"
    ]
  }
}
```

Replace `<artifactory-host>`. Add allow entries as you notice yourself approving
the same read-only command repeatedly.

---

## 2. Output style

**File:** `%USERPROFILE%\.claude\output-styles\terse-eng.md`

(Use `<repo>\.claude\output-styles\terse-eng.md` instead if you want it committed
and shared with the team.)

```markdown
---
name: terse-eng
description: Dense engineering report format
keep-coding-instructions: true
---

Respond as an engineering report, not a conversation.

Never restate my request. Never narrate what you are about to do.
No preamble. No closing summary paragraph.

For any implementation, respond in exactly this order:

1. Files changed — path + one line each
2. Why this works — max 3 sentences
3. Risks / not handled — bullets, or "none"
4. Verification — command run + result

For questions with no code change, answer in under 5 lines.

Prose: 3 sentences per paragraph, hard limit.
Noisy command output: summarize in 1-3 bullets, never paste it raw.
State conclusions directly. Skip the reasoning unless I ask for it.
If confidence is low, say so in one line rather than hedging throughout.
```

`keep-coding-instructions: true` is required — without it you lose Claude Code's
built-in engineering behaviour around scoping changes and verifying work before
declaring done.

**Activate:** `/output-style terse-eng`, or the `outputStyle` key in section 1.
Takes effect after `/clear` or on the next session.

---

## 3. Commit message hook

Written in Python rather than bash+jq, since Windows.

**File:** `<repo>\.claude\hooks\check_commit.py`

```python
import json
import re
import sys

ALLOWED = ("feat", "fix", "chore", "refactor", "test", "docs", "build", "ci")
MAX_SUBJECT = 60

data = json.load(sys.stdin)
cmd = data.get("tool_input", {}).get("command", "")

if "git commit" not in cmd:
    sys.exit(0)

m = re.search(r'-m\s+["\'](.+?)["\']', cmd, re.S)
if not m:
    sys.exit(0)

subject = m.group(1).splitlines()[0].strip()

if not re.match(rf'^({"|".join(ALLOWED)})(\(.+\))?: .+', subject):
    print(
        f"Commit subject must match '<type>: <description>' "
        f"where type is one of: {', '.join(ALLOWED)}",
        file=sys.stderr,
    )
    sys.exit(2)

if len(subject) > MAX_SUBJECT:
    print(
        f"Commit subject is {len(subject)} chars, max {MAX_SUBJECT}. Shorten it.",
        file=sys.stderr,
    )
    sys.exit(2)

sys.exit(0)
```

**Wire it** in `<repo>\.claude\settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "python \"$CLAUDE_PROJECT_DIR/.claude/hooks/check_commit.py\""
          }
        ]
      }
    ]
  }
}
```

If `python` is not on PATH in the shell Claude Code spawns, use the absolute
interpreter path.

### Semantics

- exit 0 → no objection, normal permission flow continues
- exit 2 → blocks the tool call, stderr text is fed back to Claude as feedback
- exit 1 → non-blocking warning only; the command still runs. Never use it here
- Do not mix: JSON on stdout is ignored when you exit 2

### Test before trusting it

```bash
echo {"tool_input":{"command":"git commit -m \"bad message\""}} | python .claude/hooks/check_commit.py
echo %ERRORLEVEL%
```

Expect the reason printed and `2`.

```bash
echo {"tool_input":{"command":"git commit -m \"fix: handle null tenor\""}} | python .claude/hooks/check_commit.py
echo %ERRORLEVEL%
```

Expect no output and `0`.

Quoting in cmd is awkward — easier to save the JSON to a file and pipe it:
`type test.json | python .claude\hooks\check_commit.py`

---

## 4. CLAUDE.md pairing

The hook enforces shape, not quality — it cannot tell whether `fix: handle null`
is accurate. Add the same rule to CLAUDE.md so good messages are the default and
the hook only catches drift:

```markdown
## Commits
- Subject: `<type>: <description>`, max 60 chars, imperative mood
- Types: feat, fix, chore, refactor, test, docs, build, ci
- Body only when the "why" is not obvious from the diff
- No Co-Authored-By trailer
```

---

## 5. Order of operations

1. Update settings.json, restart Claude Code, confirm the style is active
2. Work one day. Note every time output is still too long → add a rule to the style
3. Add the hook. Test standalone first, then in a session
4. Only after both are stable, copy to a second repo

Do not roll out to all repos before the style has survived a week on one.

---

## 6. Known quirks

- `PreToolUse:Bash hook error` can appear even when the hook exits 0. Verify with
  the standalone test before chasing it
- The hook runs before *every* Bash call, including `ls`. The early exit keeps it
  cheap; keep it under 500ms
- The hook only sees the command string. A commit made via `-F file` or a heredoc
  will not be matched — CLAUDE.md covers that gap
- Output style rules decay if you add too many. Keep it under ~15 lines
