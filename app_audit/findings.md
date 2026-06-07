# Forward Manager v2 — Backend Audit Findings

> **Scope:** `apps/fwdmgr/fwmdgr/**` (backend only) + fwdmgr-relevant parts of `compute-fabric/**`.
> **Excluded:** `apps/fwdmgr/ui/**`, all other apps, shared libs (except dependency edges).
> **Mode:** Read-only audit. Findings only — no code modified.
> **Severity scale:** `BLOCKER` (must fix before prod) · `SHOULD-FIX` (fix soon) · `NICE-TO-HAVE` (improvement).

---

## Phase 1 — Architecture Map
_Orientation only. No judgments. Filled after Phase 1._

- **Directory structure:**
- **Entry points:**
- **Module dependency / import graph:**
- **Config / secrets / state location:**
- **Core data flow (one operation, end to end):**
- **Tech stack in use:**
- **Open questions:**

---

## Structure & Modularity
_Phase 2._

### Worst problems
| # | Finding | File:Line | Severity |
|---|---------|-----------|----------|
| 1 |  |  |  |
| 2 |  |  |  |
| 3 |  |  |  |

### Done well
-

---

## Correctness, Error Handling & Typing
_Phase 3._

| # | Finding | File:Line | Severity |
|---|---------|-----------|----------|
| 1 |  |  |  |

**Silent-wrong-number risks (trading-critical):**
-

---

## Testing
_Phase 4._

| # | Finding | File:Line | Severity |
|---|---------|-----------|----------|
| 1 |  |  |  |

**Riskiest untested critical paths:**
-

---

## Security & Secrets
_Phase 5._

| # | Finding | File:Line | Severity |
|---|---------|-----------|----------|
| 1 |  |  |  |

---

## Dependencies & Deployment
_Phase 6._

| # | Finding | File:Line | Severity |
|---|---------|-----------|----------|
| 1 |  |  |  |

---

## Final Assessment
_Phase 7._

### Executive summary
_(4-5 sentences — production-readiness verdict for front-office trading context.)_

### All BLOCKERs
| Finding | One-line fix |
|---------|--------------|
|  |  |

### Top 5 to fix first (risk-to-effort prioritized)
1.
2.
3.
4.
5.

### What the rebuild got right
-

### Overall readiness call
_( ship / fix-then-ship / not close — with one-line justification )_
