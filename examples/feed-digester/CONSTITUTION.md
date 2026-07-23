<!-- forged-by: dark-forgery @ v0.2 (skill revision recorded so a live factory can be upgraded when the skill evolves) -->

# Feed Digester Agent Constitution

Agents operating in this repository follow these rules unconditionally.

## 1. Role discipline
You are spawned with a role. Work only within that role. Do not perform work that belongs
to another role unless the supervisor explicitly delegates it in the task brief.

## 2. Read before acting
Before touching any file, read: (1) your role doc in `docs/roles/`, (2) `CLAUDE.md`,
(3) `CONSTITUTION.md`. A task brief from the supervisor does not replace this reading step.

## 3. Output contracts are inviolable
Every interface defined in `CLAUDE.md` (API contracts, CLI output schemas, data formats) is
a hard contract. No agent may change an interface without the supervisor writing a versioned
update to `CLAUDE.md` first. Breaking a contract is not an implementation detail — it is
a blocking defect.

## 4. Every commit must pass its component's build
Run the build command for your component before committing. No broken builds in main.
If the build cannot pass due to a dependency on another component's unreleased work,
write a `BLOCKED:` entry to STATUS.md and stop.

## 5. Tests are part of the task
A task is not done until there is a test covering the new behavior. The test lives in the
same PR as the behavior. Untested PRs fail Engineer review.

## 6. Spec docs are mandatory for every PR
- New feature → create `docs/features/{slug}.md` in the same PR
- Bug fix → create or update `docs/issues/{id}.md` in the same PR
Spec format: Current state → What we need → Why. No file paths, no implementation detail.
QA uses this as their test brief. A PR with no spec doc fails review.

## 7. Fail loudly, fail fast
If a task cannot be completed (missing dependency, broken contract, ambiguous spec),
write a structured entry to STATUS.md immediately. Do not partially implement.
Format: `BLOCKED: [{Role}] {task} — {reason} — needs: {what unblocks this}`

## 8. No speculative work
Implement exactly what the task requires. No features, abstractions, or refactors
beyond scope. Three similar lines is better than a premature abstraction.

## 9. Security — never commit secrets
Never write credentials, tokens, API keys, or passwords to any committed file.
Secrets live in `.env` (gitignored) and are passed to processes via environment variables.
If you discover a secret in the codebase, flag it to the supervisor immediately.

## 10. Commit message format
`[{role}] {short description} — {what changed and why}`
Examples:
  `[engineer] add feed poller — pulls configured RSS URLs, normalizes to Item schema`
  `[qa] approve PR #7 — dedupe tests pass on the fixture corpus, no regressions found`

## 11. PR workflow — no direct commits to main
Every change goes through a PR:
  Engineer implements → opens PR
  → Supervisor spawns Reviewer Engineer → up to 3 review cycles
  → After each "changes requested" review: the acting agent addresses, pushes/updates,
    then increments that role's cycle counter in the STATUS.md PR entry
  → When any cycle counter hits its project-defined limit with no approval: agent sets
    Status to needs-human, writes a plain-English Reason → Supervisor sends the Reason to the
    user via comm channel **only if `Reason-sent` is not already `yes`**, then sets
    `Reason-sent: yes` on the entry → work on that PR stops immediately
  → On receiving user resolution: Supervisor resets cycle counts, sets Status back to
    in-review, clears both Reason and `Reason-sent`, resumes from the appropriate step
Bypass requires explicit supervisor instruction.

Because a fresh supervisor session re-scans blocked/needs-human items on every startup, the
`Reason-sent` flag is what stops the same Reason being re-sent to the user each cycle.

Cycle limits are **not defined here** — they are project-specific and live in the
CONSTITUTION project additions section (set during Phase 4 of Dark Forgery).

## 12. STATUS.md is the supervisor's domain
Only the supervisor writes to STATUS.md — with one exception: agents update their own
cycle count and Status on their active PR entry after each review response.

Every Active PR entry must follow this format:
```
### PR #N — title
- Branch: `feature/branch-name`
- Spec: `docs/features/slug.md` or `docs/issues/id.md`
- Status: open | in-review | merged | needs-human
- Phase: {role-that-acts-now}
- {Role} cycles: N / {limit}   (one line per review role; omit roles not in this project)
- Reason: ...                   (needs-human only — sent verbatim to user via comm channel)
- Reason-sent: yes | no         (needs-human only — set to yes once the Reason has been sent)
```
`Status` = big-picture state of the PR.
`Phase` = who must act right now; supervisor reads this on every startup to re-spawn.
`Reason` = plain-English explanation; sent verbatim to the user when needs-human is set.
`Reason-sent` = whether the Reason has already been delivered; the supervisor sends a Reason only
when this is not `yes`, so a per-cycle restart never re-notifies the user about the same block.
Cycle limits come from the project-specific CONSTITUTION additions, not the common core.
This makes conflict detection crash-tolerant: both signals survive process restarts.

## 13. Vault/log notes are mandatory for every feature and issue
Every PR introducing a new feature must include a note written to the configured logging
destination. Every bug fix and every regression found must produce a note. On merge, the
Engineer updates the note status. See `CLAUDE.md` "Logging" section for format and script.

---

# Project-specific additions

## 14. Review-cycle limits
These are the cycle caps referenced by common-core rules 11 and 12. When a counter reaches
its limit with no approval, the acting agent sets Status to `needs-human` and writes a Reason.

| Review role | Limit |
|---|---|
| Reviewer Engineer (code review) | 3 cycles |
| QA (testing) | 2 cycles |

There is no Designer in this factory, so no design-review cycle exists.

## 15. Digest output is a hard contract
The daily digest is this product's single user-facing artifact. Its structure is an output
contract under rule 3: the top-level markdown shape (title, date line, one `##` section per
topic cluster, bulleted items with source + link) may not change without a versioned update
to the "Digest format" section of `CLAUDE.md`. QA validates every digest against that section.

## 16. Determinism over cleverness in clustering
Topic clustering must be deterministic for a fixed input and a fixed config: same items in →
same clusters out, run to run. No wall-clock, randomness, or network calls inside the
clustering step. This is what makes QA's fixture-based tests meaningful (see rule 5). Any
non-determinism is a blocking defect, not a tuning detail.
