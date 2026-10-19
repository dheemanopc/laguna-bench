#!/usr/bin/env python3
"""laguna-bench — PreToolUse suppression guard for executor sessions (2026-10-19: reject @# noqa, type: ignore,
pytest suppressions, and other check-silencing patterns). Blocks models from silencing checks instead of fixing them.
Wired by laguna_task.sh when LAGUNA_GUARDS=1.
Policy:
  REJECTED: Any added text matching the suppression regex (except allow-listed asyncpg import).
  ALLOWED:  import asyncpg  # type: ignore[import-untyped]
Blocking = exit 2 with the reason on stderr (Claude Code feeds it back to the model).
"""
import json, re, sys, os

# Suppression regex: case-sensitive, applied per added line
SUPPRESS_RE = re.compile(r'#\s*noqa|type:\s*ignore|pytest\.mark\.(skip|xfail)|@pytest\.skip|pytest\.skip\(|eslint-disable|@ts-ignore|@ts-expect-error')

# Allow-listed patterns: lines that match are permitted even if they match SUPPRESS_RE
ALLOW_LIST = [
    re.compile(r'^\s*import asyncpg\s+# type: ignore\[import-untyped\]\s*$')
]


def deny(msg):
    print(msg, file=sys.stderr)
    sys.exit(2)


def collect_added_lines(tool_name, tool_input, cwd):
    """Extract the text being added (new lines) from the tool input."""
    added = []
    if tool_name == 'Write':
        # Write.tool_input.content
        content = tool_input.get('content', '')
        file_path = tool_input.get('file_path', '')

        # Resolve the absolute path
        abs_path = os.path.join(cwd or os.getcwd(), file_path) if not os.path.isabs(file_path) else file_path

        # If file exists and is readable, only count lines that weren't in the original
        if os.path.exists(abs_path) and os.path.isfile(abs_path):
            try:
                with open(abs_path, 'r', encoding='utf-8', errors='replace') as f:
                    original_lines = set(line.strip() for line in f.readlines())
                added = [line for line in content.split('\n') if line.strip() not in original_lines]
            except Exception:
                # If we can't read the file, treat all lines as added
                added = content.split('\n') if content else []
        else:
            # File doesn't exist, all lines are added
            added = content.split('\n') if content else []
    elif tool_name == 'Edit':
        # Edit.tool_input.new_string
        old_str = tool_input.get('old_string', '')
        new_str = tool_input.get('new_string', '')
        old_lines = set(line.strip() for line in old_str.split('\n'))
        added = [line for line in new_str.split('\n') if line.strip() not in old_lines]
    elif tool_name == 'MultiEdit':
        # MultiEdit.tool_input.edits is an array of {old_string, new_string}
        edits = tool_input.get('edits', [])
        for edit in edits:
            old_str = edit.get('old_string', '')
            new_str = edit.get('new_string', '')
            old_lines = set(line.strip() for line in old_str.split('\n'))
            added.extend([line for line in new_str.split('\n') if line.strip() not in old_lines])
    elif tool_name == 'Bash':
        # Bash: check if command writes files and matches suppression patterns
        cmd = tool_input.get('command', '')
        writes_files = any(x in cmd for x in ['sed -i', ' > ', '>>', 'tee ', 'cat <<', 'python -c', 'python3 -c', 'perl -i', 'printf ', 'echo '])
        if writes_files and SUPPRESS_RE.search(cmd):
            added = [cmd]  # Treat the whole command as added text for suppression check
    return added


def is_allowed(line):
    """Check if a line is in the allow list."""
    for pattern in ALLOW_LIST:
        if pattern.match(line):
            return True
    return False


try:
    ev = json.load(sys.stdin)
    tool_name = ev.get('tool_name', '')
    tool_input = ev.get('tool_input') or {}
    cwd = ev.get('cwd')

    if tool_name not in ['Write', 'Edit', 'MultiEdit', 'Bash']:
        sys.exit(0)

    added_lines = collect_added_lines(tool_name, tool_input, cwd)

    for line in added_lines:
        if SUPPRESS_RE.search(line) and not is_allowed(line):
            match = SUPPRESS_RE.search(line)
            matched_text = match.group(0)
            deny(f"suppress_guard: adding `{matched_text}` is not allowed. Silencing a check is rejected by the harness. "
                 f"Fix the cause instead: for asyncpg row values typed Any use `typing.cast(\"T\", value)` "
                 f"(see src/mem_mcp/mindmap/work_items.py, e.g. `return cast(\"UUID\", active_id)`); "
                 f"for ruff, change the code; for an untestable path, write a real test. "
                 f"The only allowed suppression is `import asyncpg  # type: ignore[import-untyped]`.")

    sys.exit(0)
except Exception:
    # Fail-open on malformed JSON or any exception
    sys.exit(0)
