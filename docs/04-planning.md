# 04 · Planning and design quality

**Task.** Each model wrote, in one shot:
- the F2 design doc (`docs/feature/00-goal.md`) from the feature request alone;
- the WP1 package plan (`docs/feature/wp1.md`) from the approved goal plus `wp0.md`.

**Grading.** A Sonnet reviewer graded every draft with the same rubric (requirement coverage, codebase soundness verified by grep, work-package/task quality, known-trap and known-defect checks). The reference is F2-4's multi-round, Sonnet/Opus-approved documents, which count as 8+.

| Model (precision) | Runs | Design doc | WP1 plan | Time (goal / plan) | Notes |
|---|---|---|---|---|---|
| **Reflection Beam 1.0** (FP8) | PL-G4 / PL-P4 | **6.0** | 5.5 | 2.2 / 1.7 min | Best coverage. Only design with versioned workflows (no stuck items). Missed the `change_type` CHECK trap; RLS claimed on tables without `tenant_id`. 2 oversized tasks; import cycle open. |
| **Laguna S 2.1** (BF16) | PL-G / PL-P | 5.5 | **6.5** | 54 / 44 min | False claim that `change_type` is free text (it is `CHECK IN (...)`, 0046:88). No sign-off request entity. Best task split (4 tasks), but T1–T3 share one file. |
| gpt-oss-120b (BF16) | PL-G3 / PL-P3 | 5.0 | 5.5 | 4 / 1.7 min | Role-only sign-off (no owner/proposer exclusion). Invented a drag-and-drop dependency and wrong line refs. Signatures cannot implement the exclusion rule. |
| Inkling-Small (FP8) | PL-G2 / PL-P2 | 5.0 | 5.0 | 0.8 / 1.8 min | **Tool failure**: emitted the Write call as text, so no file was saved, plus leaked self-talk. Invented `web/app/api`. 2 oversized tasks. |
| Approved reference | F2-4 | 8+ | 8+ | multi-round | Handles the import cycle, bypass routing and exclusion rules. |

**Known-defect check.** No candidate plan (and not the approved reference either) prevented the WP1 defects later found in code: `workflow_id` never set, empty-roles signing, missing `team_id` filter, and a legacy NULL-stage commit. These are planning gaps that only a code-reading reviewer caught.

**Conclusion.** No open model is a reliable planner. Every one-shot draft scored 5–6.5 against 8+. Use them for **first drafts only**, followed by mandatory Sonnet review rounds against the real code. Never let them decide schema or security.
