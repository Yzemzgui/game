# Claude Code Audit Prompts — Forward Manager v2 Backend

Feed these to Claude Code **in order**, one per phase. Don't skip ahead.
Between phases, do the senior-engineer verification described in `guide.md`.

Use `/clear` between major phases if the context gets full — architectural
judgment degrades when the window is cluttered with unrelated file reads.

---

## Prompt 0 — Frame the engagement

```
You are helping me audit a codebase. Context: this app (Forward Manager v2)
was rebuilt from scratch by traders — domain experts, not professional
software engineers — using an AI coding tool. My manager has asked me to
assess whether the v2 structure follows good software engineering standards
and is production-ready for a front-office trading environment.

Rules for this whole engagement:
- This is READ-ONLY. Do not modify, create, or refactor any code. Findings only.
- For every finding, cite the exact file path and line range as evidence.
- Rate each finding: BLOCKER / SHOULD-FIX / NICE-TO-HAVE.
- Be specific and skeptical. Do not praise code generically. If something is
  good, say why with evidence. If you're unsure, say so rather than guessing.
- We'll go in phases. Do not jump ahead. For this first message, just confirm
  you understand and wait.

Also: confirm you have read the AUDIT SCOPE in CLAUDE.md and will treat
apps/fwdmgr/ui/, other apps, and shared libs as OUT OF SCOPE. List the exact
in-scope paths back to me so I know we agree before you read anything.

Confirm you understand the engagement and the rules.
```

**→ Before continuing:** check the paths it echoes back match the real repo.

---

## Prompt 1 — Orientation / architecture map

```
Phase 1: Orientation only. Do NOT judge quality yet.
Within apps/fwdmgr/fwmdgr/ only:

Map this part of the repository for me:
- Top-level directory structure and what each part is responsible for
- Entry points (how the app starts, what runs first)
- The main modules and how they depend on each other (call out the import graph)
- Where configuration, secrets, and persistent state live
- The core data flow: trace one representative request/operation end to end
- The tech stack actually in use (frameworks, key libraries, how it's deployed)

Output a concise architecture summary. Where the intended purpose of a module
is unclear, list it as an open question rather than assuming.
Append the result to review/findings.md under the "Phase 1 — Architecture Map"
section.
```

**→ Before continuing:** read this carefully against what you know Forward
Manager v2 should be (FastAPI + Prefect + K8s). A wrong map poisons every
later phase. Correct Claude Code now if anything is off.

---

## Prompt 2 — Structure & modularity

```
Phase 2: Assess project structure and modularity against good SWE standards.
Within apps/fwdmgr/fwmdgr/ only.

Evaluate specifically:
- Separation of concerns (is business/domain logic isolated from routing,
  I/O, and framework code, or tangled together?)
- Module boundaries and cohesion — any God-files or dumping-ground modules?
- Duplication / copy-pasted logic
- Naming, consistency, and discoverability
- Whether the layering makes sense for a FastAPI + Prefect service

Give me the 3 worst structural problems first, each with file:line evidence
and a severity rating. Then a short list of what's done well, with evidence.
Append the findings to review/findings.md under "Structure & Modularity".
```

---

## Prompt 3 — Correctness, error handling, typing

```
Phase 3: Assess correctness and robustness.
Within apps/fwdmgr/fwmdgr/ only.

Look for:
- Error handling: are failures caught and surfaced sensibly, or swallowed /
  ignored / crashing? Any bare excepts?
- Input validation and boundary handling (especially anything touching
  trade/forward data or user input)
- Type hints / Pydantic usage — present, absent, or misleading?
- Concurrency or async correctness issues (blocking calls in async paths,
  shared mutable state, race conditions) — this is a Prefect/FastAPI app so
  be alert here
- Obvious correctness bugs or logic that looks wrong for the domain

Findings with file:line evidence and severity. Flag anything that could cause
silent wrong numbers — in a trading app that's a BLOCKER class. Append to
review/findings.md under "Correctness, Error Handling & Typing".
```

**→ Concurrency is your strong spot — verify what it flags here yourself
rather than taking it on faith.**

---

## Prompt 4 — Testing

```
Phase 4: Assess the test suite.
Within apps/fwdmgr/fwmdgr/ only.

- What's actually tested vs. not? Map test coverage to the critical paths you
  identified in Phase 1, not just raw coverage %.
- Are tests meaningful (asserting real behavior) or hollow (asserting mocks,
  testing nothing)?
- Is the most important domain logic — anything computing forward/trade
  numbers — covered?
- Test structure, fixtures, isolation, and whether they'd catch a regression.

Tell me the riskiest UNTESTED paths specifically. Findings with evidence and
severity. Append to review/findings.md under "Testing".
```

---

## Prompt 5 — Security & secrets

```
Phase 5: Security and secrets hygiene. This is a front-office trading app, so
hold a high bar. Within apps/fwdmgr/fwmdgr/ only.

- Hardcoded secrets, credentials, tokens, connection strings anywhere in code
  or config
- Authn/authz: is access controlled, or are endpoints open?
- Injection risks (SQL, command, etc.) and unsafe input handling
- Sensitive data in logs
- Anything that would fail a bank security review

Findings with file:line evidence and severity. Hardcoded prod secrets are
BLOCKERs. Append to review/findings.md under "Security & Secrets".
```

---

## Prompt 6 — Dependencies & deployment/config

```
Phase 6: Dependency hygiene and deployment/config soundness.

For dependencies — within apps/fwdmgr/fwmdgr/ and, for resolution only, the
workspace-root pyproject.toml / lockfile:
- Pinned or floating? Unused, outdated, or risky packages? Anything unusual
  for this kind of service?

For deployment — within compute-fabric/, ONLY the manifests/config relevant
to fwdmgr:
- Config management: separated from code and environment-aware, or hardcoded
  per environment?
- Deployment artifacts (Dockerfile, K8s manifests, Prefect deployment config):
  sane, or fragile/insecure?
- Reproducibility: could a new engineer build and run this from a clean clone?

Findings with evidence and severity. Append to review/findings.md under
"Dependencies & Deployment".
```

---

## Prompt 7 — Synthesis

```
Phase 7: Synthesize everything in review/findings.md into a final assessment.

Produce:
1. A 4-5 sentence executive summary: overall production-readiness verdict for
   a front-office trading context.
2. All BLOCKERs in one list, each with the one-line fix.
3. Top 5 things to fix first, prioritized by risk-to-effort.
4. What the rebuild got RIGHT (be fair — this was built by traders, credit
   where due).
5. An honest overall readiness call: ship / fix-then-ship / not close.

Keep it tight and evidence-backed. No filler. Write it into review/findings.md
under "Final Assessment".
```

**→ Rewrite the executive summary in your own voice before it goes to your
manager. The model drafts; you certify.**
