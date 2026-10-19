#!/usr/bin/env python3
"""laguna-bench — PreToolUse path guard for executor sessions (Anand 2026-10-16: the engineer may read/write freely
inside its work dir or temp, nothing else). Wired by run_executor.sh when PATH_GUARD=1; usage in the hook command:
    path_guard.py <run_dir>
Policy:
  read+write : <run_dir>/**, /tmp/**, /dev/null
  read/exec  : the bench test venv, the web node_modules target, system dirs (/usr, /bin, /lib, /etc/ssl, /proc/self ...)
  denied     : anything else, '~' / $HOME expansions, '..' that resolves outside the run dir.
Blocking = exit 2 with the reason on stderr (Claude Code feeds it back to the model so it can adapt instead of giving up).
Bash commands are checked token-wise (prefix permission rules cannot express paths); file tools by their path argument.
Defence in depth, not a sandbox: an obfuscated command (e.g. building a path at runtime) can evade it."""
import json, os, re, shlex, sys

RUN = os.path.realpath(sys.argv[1])
RW = [RUN, '/tmp', '/dev/null', '/dev/stdout', '/dev/stderr']
RO = ['/usr', '/bin', '/lib', '/lib64', '/sbin', '/etc/ssl', '/etc/ca-certificates', '/proc/self', '/opt',
      os.path.expanduser('~/laguna-bench/wt/lead/.venv'), '/codes/ai-work/memory-man/web/node_modules',
      os.path.expanduser('~/.local/bin'), os.path.expanduser('~/.nvm'), os.path.expanduser('~/.cache/uv')]
WRITE_TOOLS = {'Edit', 'Write', 'MultiEdit', 'NotebookEdit'}


def under(p, roots):
    return any(p == r or p.startswith(r.rstrip('/') + '/') for r in roots)


def deny(msg):
    print(f"path_guard: {msg}. You may read/write only inside {RUN} (your repo) or /tmp; "
          f"use relative paths inside the repo.", file=sys.stderr)
    sys.exit(2)


def check_path(raw, cwd, write):
    if raw.startswith('~') or '$HOME' in raw or '${HOME' in raw:
        deny(f"'{raw}' points into the home directory")
    p = os.path.realpath(os.path.join(cwd, raw))
    if under(p, RW):
        return
    if not write and under(p, RO):
        return
    deny(f"'{raw}' resolves to {p}, outside the allowed area" + (' (read-only area)' if under(p, RO) else ''))


# Web access (Anand 2026-10-17: Laguna may use the internet for docs on a fresh feature): GET only, allow-listed doc hosts.
WEB_OK = ('pypi.org', 'files.pythonhosted.org', 'docs.python.org', 'fastapi.tiangolo.com', 'docs.sqlalchemy.org',
          'alembic.sqlalchemy.org', 'magicstack.github.io', 'www.postgresql.org', 'nextjs.org', 'react.dev',
          'www.typescriptlang.org', 'playwright.dev', 'www.npmjs.com', 'registry.npmjs.org', 'raw.githubusercontent.com',
          'github.com', 'docs.pydantic.dev', 'docs.pytest.org', 'tailwindcss.com')


def check_url(u):
    host = re.sub(r'^[a-z]+://', '', u).split('/')[0].split(':')[0].lower()
    if not any(host == h or host.endswith('.' + h) for h in WEB_OK):
        print(f"path_guard: web host '{host}' is not on the docs allow-list ({', '.join(WEB_OK)}).", file=sys.stderr)
        sys.exit(2)


ev = json.load(sys.stdin)
tool, inp = ev.get('tool_name', ''), ev.get('tool_input') or {}
cwd = ev.get('cwd') or RUN
if tool == 'WebFetch':
    check_url(inp.get('url', ''))
    sys.exit(0)
if tool == 'Bash':
    cmd = inp.get('command', '')
    if re.search(r'\b(curl|wget)\b', cmd):
        if re.search(r'(\s-(d|F|T|X)\b|--data|--form|--upload-file|--request|-X\s*(POST|PUT|PATCH|DELETE))', cmd):
            print("path_guard: web access is GET-only (no -d/-F/-T/-X/--data/--form/--upload-file).", file=sys.stderr)
            sys.exit(2)
        urls = re.findall(r'https?://[^\s\'"]+', cmd)
        if not urls:
            print("path_guard: curl/wget needs an explicit https:// URL on the docs allow-list.", file=sys.stderr)
            sys.exit(2)
        for u in urls:
            check_url(u)
    try:
        toks = shlex.split(cmd, comments=True)
    except ValueError:
        toks = cmd.split()
    for t in toks:
        # split redirections / assignments like >/x, 2>/x, VAR=/x, --opt=/x
        if re.match(r'^[a-z]+://', t):
            continue
        for part in re.split(r'[=<>&|;]+', t):
            if part.startswith(('/', '~', '$HOME', '${HOME')) or '..' in part.split('/'):
                write = bool(re.search(r'(^|\s)(rm|mv|cp|mkdir|touch|tee|ln|chmod|truncate|install|rsync|dd)\b', cmd)) or '>' in t
                check_path(part, cwd, write)
elif tool in WRITE_TOOLS or tool in {'Read', 'Glob', 'Grep'}:
    for k in ('file_path', 'notebook_path', 'path'):
        if inp.get(k):
            check_path(inp[k], cwd, tool in WRITE_TOOLS)
sys.exit(0)
