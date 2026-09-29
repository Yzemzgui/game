---
name: pr-comments
description: Turn an existing pr-review report (reviews/<pr>-<branch>.md) into ready-to-post GitHub PR comments written in the reviewer's own voice, with verified line anchors and one-click suggestion blocks. Use after pr-review has run, whenever asked for PR comments, comments to post, review comments, or "comments for PR <n>". Does not review code itself; it only works from the report.
---

# PR comments

Input: a PR number, URL, or branch. Output: `reviews/<L>-comments.md`, where `L` is the label pr-review used (`<pr-number>-<branch>` with `/` replaced by `-`) and `W = reviews/.work/L`.

This skill never reviews code. The report is the source of truth; everything here is selection, anchoring, and wording. That is what keeps it fast.

## 1. Load and check the report

1. Find `reviews/L.md`. If it does not exist, stop and say: "No report for this PR, run pr-review first." Do not run the review yourself.
2. Read its `Head:` and `Base:` fields. Run `git fetch --quiet origin <branch>` and compare `git rev-parse origin/<branch>` with `Head:`. If they differ, stop and say the branch moved since the review, so findings and line numbers may be wrong; a pr-review re-review will be quick. Do not write comments against a stale report.

## 2. Select

Post only the findings worth posting:
- every Blocker,
- every Major with `Changes behavior: yes`.

A Major that does not change behavior does not belong here: missing tests, loose assertions, dead code, and reuse or naming complaints stay in the report no matter how much they matter. Minors and Nits stay in the report unless the user asks for them. Unverified findings are never posted. The "No PR description" finding is not a line comment; skip it.

**Already raised.** If `gh` is available, fetch existing review comments once:

    gh api repos/{owner}/{repo}/pulls/<number>/comments --paginate --jq '.[] | "\(.path):\(.line // .original_line) \(.user.login): \(.body | gsub("\n"; " ") | .[0:150])"'

Drop any selected finding that someone already raised on the same file, near the same line, making the same point. List it under `## Already raised` with the commenter, so the reviewer can resolve or reply instead of duplicating.

**Group** findings that share a root cause into one comment on the primary line, referencing the secondary line numbers in prose. Do not open a second comment for the same fix.

## 3. Verify anchors (mandatory, one call)

Run once for all anchors:

    bash <this skill's dir>/scripts/anchors.sh origin/<base> <head sha> <path:line> <path:line> ...

It prints, per anchor, `in-diff` or `outside-diff` and the exact source text of that line at the reviewed head. Paste the returned text into the heading. Line numbers estimated from a diff are wrong often enough to send the author to the wrong line.

- If the text does not match what the finding is about (blank line, unrelated code), find the right line in that file at the head SHA (`git show <sha>:<path> | grep -n "<identifier>"`) and re-run the script for the corrected anchors.
- GitHub only accepts line comments inside the PR's diff hunks. For an `outside-diff` anchor, add `(outside the diff: post as a file comment, or on line <N>)` to the heading, where `<N>` is the nearest `in-diff` line that carries the same point.

## 4. Write the file

Write `reviews/L-comments.md` with these sections, in this order, so the author can tell at a glance what must change from what should:

    ## Must fix before merge
    <every Blocker>

    ## Behavior changes worth fixing
    <every Major that changes behavior>

    ## Your call
    <any finding whose severity depends on context you could not establish, with the one question that would settle it>

    ## Already raised
    <one line each, only if any>

Keep the first two headings even when a section is empty; write `_None._` under an empty one. The headings are the only place severity may be named: inside a comment body the voice rules below still forbid it, and the author sees only the body when it is posted. Order entries within each section most-severe first.

Each entry has three parts, in this order:

    ### `<path>`, line **<n>**  (`<exact source text of that line>`)

    <the comment body, ready to paste, nothing else>

    **For you:** <2-5 sentences explaining the finding to the reviewer: the mechanism, why it matters, and what you could not verify. This part is NOT posted.>

    ---

When the fix is a literal replacement of the anchored line(s), give it as a GitHub suggestion block so the author can apply it in one click:

    ```suggestion
    <replacement lines>
    ```

The report's `Suggested fix:` line is a starting point, not text to copy.

When done, print only the file path and the number of comments per section.

## Comment voice

These comments are posted under the reviewer's name to a colleague. Write how an engineer writes in a PR, not how a report writes.

- Never use the severity words. No "Blocker", "Major", "Critical", no bold verdict openers.
- State the mechanism, not the machinery behind it. "`urlopen` raises `HTTPError` for non-2xx" not "`urlopen` uses the default opener, which installs `HTTPDefaultErrorHandler`, which raises...".
- One sentence of consequence, then stop. Do not chain "so X, and then Y never fires, and therefore Z documented in the README never executes."
- One fix. Not "or alternatively". If two fixes exist, pick the one that leaves the cleaner code.
- Do not scope a claim to an environment. "never raised" not "never raised in production".
- Ask about intent, do not assert it. "Why an 8 hour window?" not "Where does this come from?" and not "This appears to be arbitrary."
- Do not speculate about motive in the comment ("unless this works around..."). If the motive matters, ask.
- Attribute facts to their source: "5 days per the README", not "5 days".
- Never cite a number taken from a test fixture as system behavior. Test data is not evidence about the service.
- No labels like "Fix:", "Problem:", "Evidence:". Those belong in the report, not the comment.
- Prefer a question over an instruction when the author may know something you don't.
- Keep it under ~4 sentences plus a code block.
- No em dashes.
