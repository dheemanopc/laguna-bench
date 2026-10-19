You are the tech lead. Developers have implemented work packages WP1 and WP2 of the design in ~/laguna-bench/verify/F1-1/spec/DESIGN.md
(business brief: ~/laguna-bench/verify/F1-1/spec/BRIEF.md). You will NOT read their code. Instead write a VERIFICATION PLAN that an independent
verifier engineer will execute against the delivered code, to decide pass/fail for this round.
The verifier can read the repository, run pytest/alembic/ruff/mypy against its own test database, and ADD new test files
under tests/verify/ (it must not change src/ or existing tests). It sees only the repo and your plan.
Write the plan with the Write tool to ~/laguna-bench/verify/F1-1/VERIFY_PLAN.md and end your turn. The plan must be concrete and executable:
numbered checks (V1..Vn), each with: the brief acceptance criterion / design rule it covers, the exact scenario
(setup, action, expected observable result), and how to check it (which test to write or command to run). Cover the
business rules that WP1+WP2 claim (states/transitions, reasons, permissions, history append-only and complete, tenant
isolation, concurrency guard, archived maps, error mapping) and the project's own gates (full suite vs pre-existing
failures, ruff, mypy, alembic single head, tenant-scope lint). Prefer checks that would catch a REAL regression.
Nobody will answer questions; do not ask any.
