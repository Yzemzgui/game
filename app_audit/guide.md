# Collaboration Guide — Auditing Forward Manager v2 with Claude Code

This is how to run the audit like a super-senior engineer: Claude Code does
the legwork, you supply the judgment and certify the result. Your name is on
this review — the value you add over "I asked an AI" is your own verification.

---

## The files in this folder

| File | What it is | Where it goes |
|------|-----------|---------------|
| `CLAUDE.md` | Scope + engagement rules Claude Code reads every turn | **Top of the repo's `CLAUDE.md`** (merge into existing if present) |
| `prompts.md` | The 8 phase prompts, in order | Keep open beside your terminal; paste one per phase |
| `findings.md` | Pre-structured findings template | Copy to **`review/findings.md`** in the repo |
| `guide.md` | This file | Reference |

---

## Should you set up findings.md, or let Claude Code?

**You set it up.** Copy the provided `findings.md` to `review/findings.md`
yourself before you start. Reasons:
- The phase prompts say "append to review/findings.md under [section]" — the
  headings must already exist for the appends to land cleanly.
- You control the structure (severity scale, section order) instead of letting
  it drift.
- If you let Claude Code create it, it'll invent its own format and you lose
  consistency across phases and sessions.

So: `mkdir review && cp findings.md review/findings.md` in the repo, then run
the prompts.

---

## One-time setup on the work laptop

1. Move this folder to the laptop.
2. **Verify the real paths first:** `ls apps/` and `ls apps/fwdmgr/`. During
   planning two spellings appeared (`fwmgr/fwmdgr` vs `fwdmgr`). Fix every path
   in `CLAUDE.md` AND `prompts.md` to match the repo exactly. This is the one
   thing that breaks scoping if wrong.
3. Merge `CLAUDE.md`'s scope block into the repo's `CLAUDE.md` (create it if
   there isn't one; consider `/init` first for a baseline project map).
4. `mkdir review && cp findings.md review/findings.md`.
5. Launch Claude Code **from the repo root** — NOT inside the app directory.
   You need `compute-fabric/` reachable for Phase 6, and `cd`-ing into the app
   would cut it off.

---

## The rhythm: prompt → verify → next

The prompts are the easy half. Quality comes from what you do in the gaps.

### After every phase, do these four things

**1. Spot-check the extremes.** Open the single worst finding and the single
best one yourself. If it calls something a BLOCKER, confirm the cited lines
actually say what it claims. Models occasionally misread or hallucinate a
problem — your independent read is what makes this *your* review.

**2. Push back on soft severities.** If a SHOULD-FIX looks like a blocker to
you (or vice versa), say:
> "Why is X only SHOULD-FIX? In a trading app a silent numeric error is a
> blocker — re-rate and justify."
Forcing it to defend ratings surfaces sloppy judgment.

**3. Make it show, not tell.** Any abstract finding ("error handling is weak")
gets:
> "Show me the three worst examples with exact lines."
Vague findings are unverifiable and useless in a manager writeup.

**4. Keep it in audit mode.** Trader-built code invites the urge to refactor.
If it starts proposing rewrites:
> "Findings only for now. We're assessing, not fixing."

### Phase-specific watch points

- **Phase 1:** The map is load-bearing. Check it against what you know v2 is
  (FastAPI + Prefect + K8s) before going further. Fix errors now.
- **Phase 3:** Concurrency/async is your strength (the threading/GIL/asyncio
  work). Verify its async findings personally — you're better placed than the
  model to catch a real race vs. a false alarm.
- **Phase 5:** Hold a bank-grade bar. A hardcoded prod secret is a hard
  blocker, full stop.
- **Phase 6:** Let it read the workspace-root `pyproject.toml`/lockfile for
  dependency resolution, but don't let it audit other apps' deps.

---

## Token discipline

- Scope block + per-prompt "Within apps/fwdmgr/fwmdgr/ only:" keeps it off the
  UI and sibling apps.
- `/clear` between major phases — don't carry one phase's file reads into the
  next.
- If it announces it's about to read something out of scope, stop it. The
  scope block tells it to ask first; hold it to that.

---

## Delivering to your manager

Take Phase 7's output and **rewrite the executive summary in your own voice.**
The model drafts; you certify.

Framing that lands well:
- **Lead with what the rebuild got right**, then the path to production, then
  the blockers. A trader-built app that's 80% there is a genuinely good
  outcome — say so.
- Position it as a **production-readiness assessment with prioritized next
  steps**, not a critique of the traders. Constructive reads better than
  gatekeeping, and it's the more accurate story.
- Keep the final doc tight: architecture overview, findings by severity, top 5
  to fix, overall readiness call.
