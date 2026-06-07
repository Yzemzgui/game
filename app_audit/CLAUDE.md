# AUDIT SCOPE — STRICT

> ⚠️ Confirm the real paths with `ls apps/` and `ls apps/fwdmgr/` before
> trusting this file. Two spellings were in play during planning
> (`fwmgr/fwmdgr` vs `fwdmgr`). Fix every path below to match the repo
> exactly — a wrong path here is the one thing that breaks the whole scoping.

This is a monorepo. I am ONLY auditing the **Forward Manager backend**.

## IN SCOPE
- `apps/fwdmgr/fwmdgr/**` — backend application code (the whole review focus)
- `compute-fabric/**` — deployment files, but ONLY the parts relevant to fwdmgr

## OUT OF SCOPE — do not read, grep, or reference unless I explicitly ask
- `apps/fwdmgr/ui/**` — frontend, excluded
- Every other app under `apps/` except fwdmgr
- Every lib / shared package, EXCEPT where fwdmgr imports from it — in which
  case note the dependency edge, but do NOT audit the lib's internals

## RULES
- If you need something outside scope to understand fwdmgr, **ASK first** and
  explain why. Never read out-of-scope files speculatively.
- For dependency resolution only, you MAY read the workspace-root
  `pyproject.toml` / lockfile (uv workspace) — but only to resolve fwdmgr's
  own dependencies, not to audit other apps.

## ENGAGEMENT MODE
- This is a **READ-ONLY audit**. Do not modify, create, or refactor code.
  Findings only.
- Every finding cites an exact **file path + line range** as evidence.
- Every finding is rated **BLOCKER / SHOULD-FIX / NICE-TO-HAVE**.
- Be specific and skeptical. No generic praise. If unsure, say so.
