#!/usr/bin/env python3
"""laguna-bench — Stop hook to ensure test files exist before finishing (2026-10-19).
Ensures the planned test files listed in LAGUNA_TASK_TESTS are created before the session finishes.
Wired by laguna_task.sh when LAGUNA_GUARDS=1.
Blocking = exit 2 with the reason on stderr (Claude Code feeds it back to the model).
"""
import json, os, sys

try:
    ev = json.load(sys.stdin)

    # Avoid infinite loops: if this hook is already running, don't block again
    if ev.get('stop_hook_active'):
        sys.exit(0)

    # Get the list of planned test files from the environment
    tests_env = os.environ.get('LAGUNA_TASK_TESTS', '').strip()
    if not tests_env:
        sys.exit(0)

    # Parse the comma-separated list of test file paths
    test_files = [t.strip() for t in tests_env.split(',') if t.strip()]
    if not test_files:
        sys.exit(0)

    # Use cwd from the hook event, fall back to current directory
    cwd = ev.get('cwd') or os.getcwd()

    # Check which test files are missing
    missing = []
    for test_path in test_files:
        full_path = os.path.join(cwd, test_path)
        if not os.path.exists(full_path):
            missing.append(test_path)

    # If any test files are missing, block the finish
    if missing:
        msg = (f"finish_guard: the planned test file(s) {', '.join(missing)} do not exist yet. "
               f"The plan requires tests at exactly these paths. Create them there (move tests you wrote elsewhere), "
               f"run them, then finish.")
        print(msg, file=sys.stderr)
        sys.exit(2)

    sys.exit(0)
except Exception:
    # Fail-open on any exception
    sys.exit(0)
