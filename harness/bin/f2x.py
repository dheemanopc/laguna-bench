#!/usr/bin/env python3
"""laguna-bench F2-4 harness — "f2x" (Anand 2026-10-17).
Design (agreed with Anand): one Opus session for the whole run (goal sign-off, escalations, acceptance); one Sonnet
delivery lead (DA) session alive for the whole run, consulted only for judgment; Laguna does all planning and building,
one level at a time, every task in a FRESH session sized to stay far below auto-compaction (context watchdog: planning sessions (goal-*, plan-*) 200k, execution tasks 100k (F2-4, 11:40Z)).
Routine routing is THIS script, not an LLM: task queue from Laguna's plan, parallel Laguna sessions in one shared
working tree (file ownership locks, exclusive packages such as migrations), per-task gates, automatic retries with the
gate output, per-package milestone gates, commits per task. Every Claude call is logged with its cost (calls.jsonl).
Usage: f2x.py <run_id> [--task F2] [--slots 3] [--hard-cap-min 360] [--claude-budget 12] [--no-peer-review]
State: runs/<id>/state.json (resumable), ledger.md (journal), calls.jsonl (Claude cost), t/ (Laguna sessions), gates/."""
import argparse, json, os, re, subprocess, sys, threading, time, uuid
from concurrent.futures import ThreadPoolExecutor

B = os.path.expanduser('~/laguna-bench'); TPL = f'{B}/templates'
ap = argparse.ArgumentParser()
ap.add_argument('rid'); ap.add_argument('--task', default='F2'); ap.add_argument('--slots', type=int, default=3)
ap.add_argument('--hard-cap-min', type=int, default=360); ap.add_argument('--target-min', type=int, default=240)
ap.add_argument('--claude-budget', type=float, default=12.0); ap.add_argument('--no-peer-review', action='store_true')
ap.add_argument('--max-attempts', type=int, default=3)
A = ap.parse_args()
RD = f'{B}/runs/{A.rid}'; REPO = f'{RD}/repo'; ORD = f'{RD}/orders'
if not os.path.isdir(REPO):
    subprocess.run([f'{B}/bin/prepare_run.sh', A.task, A.rid], check=True, stdout=subprocess.DEVNULL)
os.makedirs(ORD, exist_ok=True); os.makedirs(f'{RD}/gates', exist_ok=True); os.makedirs(f'{RD}/t', exist_ok=True); os.makedirs(f'{RD}/prompts', exist_ok=True)
BASE = open(f'{RD}/baseline_sha').read().strip()
PACKET = open(f'{B}/tasks/{A.task}/packet.md').read()
RULES = open(f'{TPL}/rules.md').read()
SF = f'{RD}/state.json'
S = json.load(open(SF)) if os.path.exists(SF) else {'t0': time.time(), 'tasks': {}, 'wps': [], 'phase': 'goal',
                                                     'da_sid': str(uuid.uuid4()), 'opus_sid': str(uuid.uuid4()),
                                                     'da_started': False, 'opus_started': False, 'milestones': {}}
LOCK = threading.RLock(); DA_LOCK = threading.Lock(); OPUS_LOCK = threading.Lock(); GIT_LOCK = threading.Lock()


def save():
    with LOCK:
        json.dump(S, open(SF + '.tmp', 'w'), indent=1); os.replace(SF + '.tmp', SF)


def now():
    return time.strftime('%H:%M:%S', time.gmtime())


def log(msg):
    with LOCK:
        line = f'{now()}Z +{(time.time() - S["t0"]) / 60:.0f}m {msg}'
        open(f'{RD}/ledger.md', 'a').write(line + '\n'); print(line, flush=True)


def elapsed_min():
    return (time.time() - S['t0']) / 60


def section(path, name):
    txt = open(path).read()
    m = re.search(rf'^## {re.escape(name)}\n(.*?)(?=^## |\Z)', txt, re.S | re.M)
    return m.group(1).strip()


def fill(t, **kw):
    for k, v in kw.items():
        t = t.replace('{' + k + '}', str(v))
    return t


def last_json(text):
    blocks = re.findall(r'```json\s*(.*?)```', text or '', re.S)
    for b in reversed(blocks):
        try:
            return json.loads(b)
        except Exception:
            continue
    return None


def claude_cost():
    tot = 0.0
    if os.path.exists(f'{RD}/calls.jsonl'):
        for l in open(f'{RD}/calls.jsonl'):
            try:
                tot += json.loads(l).get('cost_usd') or 0
            except Exception:
                pass
    return tot


# ---------------- Claude sessions (persistent: --session-id first, then --resume) ----------------
SETTINGS = json.dumps({'autoMemoryEnabled': False, 'claudeMdExcludes': [os.path.expanduser('~/.claude/CLAUDE.md'), '**/.claude/CLAUDE.md']})
CENV = {'HOME': os.environ['HOME'], 'USER': os.environ.get('USER', 'anand'), 'LANG': 'C.UTF-8', 'TERM': 'dumb',
        'PATH': f"{os.path.expanduser('~/.local/bin')}:{os.path.dirname(subprocess.getoutput('command -v node'))}:/usr/local/bin:/usr/bin:/bin",
        'CLAUDE_CODE_DISABLE_AUTO_MEMORY': '1', 'DISABLE_AUTOUPDATER': '1', 'CLAUDE_CODE_SUBAGENT_MODEL': 'sonnet'}
RO_GIT = ['Bash(git diff:*)', 'Bash(git status:*)', 'Bash(git log:*)', 'Bash(git show:*)']


def claude_call(role, event, prompt, timeout=2400):
    """role 'da' (Sonnet) or 'opus'. Serialized per role (one live session each)."""
    lock = DA_LOCK if role == 'da' else OPUS_LOCK
    with lock:
        model = 'sonnet' if role == 'da' else 'opus'
        started = S[f'{role}_started']; sid = S[f'{role}_sid']
        if not started:
            init = fill(section(f'{TPL}/{"da" if role == "da" else "opus"}.md', 'INIT'), REPO=REPO, PACKET=PACKET)
            prompt = init.replace('Reply now with ```json {"ready": true} ``` only.', '') + '\n\n' + prompt
        allowed = ['Read', 'Grep', 'Glob'] + RO_GIT + (['Agent'] if role == 'da' else [f'Write(/{ORD}/**)', f'Edit(/{ORD}/**)'])
        deny = ['WebSearch', 'WebFetch', 'NotebookEdit', 'EnterPlanMode', 'ExitPlanMode', 'EnterWorktree', 'ExitWorktree',
                f'Edit(/{REPO}/**)', f'Write(/{REPO}/**)']
        cmd = ['claude', '-p', prompt, '--output-format', 'json', '--model', model, '--setting-sources', 'project',
               '--settings', SETTINGS, '--strict-mcp-config', '--mcp-config', '{"mcpServers":{}}', '--disable-slash-commands',
               '--add-dir', ORD, '--allowedTools', *allowed, '--disallowedTools', *deny]
        cmd += (['--resume', sid] if started else ['--session-id', sid])
        pf = f'{RD}/prompts/{role}-{event}-{int(time.time())}.md'; open(pf, 'w').write(prompt)
        t0 = time.time()
        p = subprocess.run(cmd, cwd=REPO, env=CENV, capture_output=True, text=True, timeout=timeout)
        try:
            r = json.loads(p.stdout)
        except Exception:
            r = {'result': p.stdout[-2000:], 'is_error': True}
        prev = S.get(f'{role}_cum', 0); S[f'{role}_started'] = True
        if r.get('total_cost_usd') is not None:
            S[f'{role}_cum'] = r['total_cost_usd']   # Claude Code reports the SESSION's cumulative cost; we log per-call deltas
        save()
        rec = {'t': now(), 'role': role, 'model': model, 'event': event, 'wall_s': round(time.time() - t0),
               'cost_usd': round(max(0.0, (r.get('total_cost_usd') or 0) - prev), 5), 'session_cum_usd': r.get('total_cost_usd'), 'usage': r.get('usage'), 'is_error': r.get('is_error'),
               'prompt_chars': len(prompt), 'result_chars': len(r.get('result') or '')}
        open(f'{RD}/calls.jsonl', 'a').write(json.dumps(rec) + '\n')
        open(f'{ORD}/{role}-{event}-{int(t0)}.md', 'w').write(r.get('result') or p.stderr[-2000:])
        log(f'{role} {event}: ${rec["cost_usd"] or 0:.3f} in {rec["wall_s"]}s (claude total ${claude_cost():.2f})')
        return last_json(r.get('result')), r.get('result') or ''


def da(event, **kw):
    if claude_cost() > A.claude_budget:
        log(f'DA {event}: Claude budget ${A.claude_budget} exceeded -> auto-approve'); return None, ''
    return claude_call('da', event, fill(section(f'{TPL}/da.md', event), REPO=REPO, BASE=BASE, **kw))


def opus(event, **kw):
    return claude_call('opus', event, fill(section(f'{TPL}/opus.md', event), REPO=REPO, ORDERS=ORD, **kw))


# ---------------- Laguna sessions ----------------
def laguna(key, prompt, mode='rw'):
    pf = f'{RD}/prompts/{key}.md'; open(pf, 'w').write(prompt)
    p = subprocess.run([f'{B}/bin/laguna_task.sh', A.rid, key, pf, mode], capture_output=True, text=True)
    try:
        m = json.loads(p.stdout[p.stdout.index('{'):]) if '{' in p.stdout else {'status': 'error', 'result': p.stderr[-500:]}
    except Exception:
        m = {'status': 'error', 'result': p.stdout[-500:] + p.stderr[-500:]}
    log(f'laguna {key}: {m.get("status")} {m.get("wall_s", 0)}s ctx_max={m.get("ctx_max")}')
    return m


def gate(key, files, tests):
    p = subprocess.run([f'{B}/bin/task_gate.sh', A.rid, key, ','.join(files), ','.join(tests)], capture_output=True, text=True)
    out = p.stdout + p.stderr[-500:]; open(f'{RD}/gates/{key}.md', 'w').write(out)
    return p.returncode == 0, out


def milestone(label):
    p = subprocess.run([f'{B}/bin/milestone_gate.sh', A.rid, label], capture_output=True, text=True)
    return p.returncode == 0, p.stdout


def commit(key, title, files):
    with GIT_LOCK:
        for _ in range(5):
            subprocess.run(['git', 'add', '-A', '--', *files], cwd=REPO, capture_output=True)
            p = subprocess.run(['git', 'commit', '-q', '-m', f'{key}: {title}', '--', *files], cwd=REPO, capture_output=True, text=True)
            if p.returncode == 0 or 'nothing' in (p.stdout + p.stderr):
                return
            time.sleep(2)


def commit_all(msg):
    with GIT_LOCK:
        subprocess.run(['git', 'add', '-A'], cwd=REPO, capture_output=True)
        subprocess.run(['git', 'commit', '-q', '-m', msg], cwd=REPO, capture_output=True)


# ---------------- Phase 1: goal (feature -> work packages) ----------------
def phase_goal():
    findings = []; rnd = 0; da_rounds = 0; da_ok = False; opus_done = False
    while rnd < 3:
        rnd += 1
        extra = '' if rnd == 1 else ('\nREVISION: `docs/feature/00-goal.md` exists; revise it (edit, do not start over) to resolve these '
                                     'findings, then list them under CHECKLIST:\n' + '\n'.join(f'#{i + 1} {f}' for i, f in enumerate(findings)))
        laguna(f'goal-r{rnd}', fill(open(f'{TPL}/goal.md').read(), RULES=RULES, PACKET=PACKET) + extra)
        if not goal_json():
            laguna(f'goal-r{rnd}-fix', 'The file docs/feature/00-goal.md is missing or does not end with a valid ```json '
                                       '{"wps":[...]} block. Fix only that (read the file first), then end with the response format.\n\n' + RULES)
        if not da_ok and da_rounds < 2:
            v, _ = da('goal_review', ROUND=da_rounds + 1); da_rounds += 1
            if v and v.get('verdict') == 'REVISE' and v.get('findings'):
                findings = v['findings']; continue
            da_ok = True; S['da_goal_notes'] = '; '.join((v or {}).get('findings') or []) or 'none'
        if not opus_done:
            o, _ = opus('goal_signoff', DA_NOTES=S.get('da_goal_notes', 'none')); opus_done = True
            if o and o.get('verdict') == 'REVISE' and o.get('findings'):
                findings = o['findings']; log('opus asked for a goal revision'); continue
        break
    g = goal_json()
    if not g:
        log('FATAL: no valid goal json'); sys.exit(2)
    S['wps'] = g['wps']; S['phase'] = 'plans'; save()
    log(f'goal done: {len(g["wps"])} WPs: ' + ', '.join(w['id'] for w in g['wps']))


def goal_json():
    try:
        j = last_json(open(f'{REPO}/docs/feature/00-goal.md').read())
        return j if j and j.get('wps') else None
    except Exception:
        return None


def wp_tasks(wid):
    try:
        j = last_json(open(f'{REPO}/docs/feature/{wid.lower()}.md').read())
        return j.get('tasks') if j else None
    except Exception:
        return None


# ---------------- Phase 2: package plans (package -> tasks), parallel ----------------
def plan_prompt(w, extra=''):
    deps = [d for d in w.get('depends_on', []) if os.path.exists(f'{REPO}/docs/feature/{d.lower()}.md')]
    dep_docs = ('Plans of the packages you build on (read their DESIGN sections): ' + ', '.join(f'docs/feature/{d.lower()}.md' for d in deps) + '\n') if deps else ''
    return fill(open(f'{TPL}/wp_plan.md').read(), RULES=RULES, WPID=w['id'], WPLOW=w['id'].lower(), WPTITLE=w['title'], DEP_DOCS=dep_docs) + extra


def phase_plans():
    wps = S['wps']; done = set(); pool = ThreadPoolExecutor(A.slots)
    # waves: a package is planned once the packages it depends on have plans (their interfaces are then concrete)
    while len(done) < len(wps):
        wave = [w for w in wps if w['id'] not in done and all(d in done or d not in [x['id'] for x in wps] for d in w.get('depends_on', []))]
        if not wave:
            wave = [w for w in wps if w['id'] not in done]
        list(pool.map(lambda w: plan_one(w), wave)); done |= {w['id'] for w in wave}
    for rnd in (1, 2):
        docs = [f'docs/feature/{w["id"].lower()}.md' for w in wps]
        v, _ = da('wp_plans_review', ROUND=rnd, DOCS=', '.join(docs))
        bad = {k: x['findings'] for k, x in ((v or {}).get('verdicts') or {}).items() if x.get('verdict') == 'REVISE' and x.get('findings')}
        if not bad or rnd == 2:
            break
        redo = [w for w in wps if w['id'] in bad]
        list(pool.map(lambda w: plan_one(w, '\nREVISION: your plan exists; revise it (edit) to resolve these findings, list them under CHECKLIST:\n'
                                         + '\n'.join(f'#{i + 1} {f}' for i, f in enumerate(bad[w['id']])), rnd + 1), redo))
    build_tasks(); S['phase'] = 'dev'; save()


def plan_one(w, extra='', rnd=1):
    m = laguna(f'plan-{w["id"].lower()}-r{rnd}', plan_prompt(w, extra))
    if not wp_tasks(w['id']):
        laguna(f'plan-{w["id"].lower()}-r{rnd}-fix', f'docs/feature/{w["id"].lower()}.md is missing or does not end with a valid '
               '```json {"tasks":[...]} block. Fix only that (read the file first), then end with the response format.\n\n' + RULES)
    return m


def build_tasks():
    wps = S['wps']; T = {}
    for w in wps:
        for t in (wp_tasks(w['id']) or []):
            tid = t['id']
            T[tid] = {'id': tid, 'wp': w['id'], 'title': t.get('title', ''), 'files': t.get('files') or [], 'tests': t.get('tests') or [],
                      'deps': t.get('deps') or [], 'acceptance': t.get('acceptance') or [], 'context': t.get('context') or [],
                      'exclusive': bool(w.get('exclusive')), 'status': 'todo', 'attempts': 0, 'conts': 0, 'notes': ''}
    # package-level deps: a task also waits for every task of the packages its package depends on
    wdeps = {w['id']: w.get('depends_on', []) for w in wps}
    for t in T.values():
        exp = set()
        for d in t['deps'] + wdeps.get(t['wp'], []):
            if d in T:
                exp.add(d)
            elif d in wdeps:
                exp |= {x for x in T if T[x]['wp'] == d}
        exp.discard(t['id']); t['deps'] = sorted(exp)
    S['tasks'] = T; save()
    log(f'tasks: {len(T)} across {len(wps)} WPs')


# ---------------- Phase 3: dev (parallel tasks, shared tree) ----------------
def task_prompt(t, previous=''):
    T = S['tasks']
    dd = [f'{d} ({T[d]["title"]})' for d in t['deps'] if d in T and T[d]['wp'] == t['wp']] or ['none']
    return fill(open(f'{TPL}/task.md').read(), RULES=RULES, WPLOW=t['wp'].lower(), TID=t['id'], TITLE=t['title'],
                FILES=', '.join(t['files']) or '(decide; keep it small)', TESTS=', '.join(t['tests']) or 'none',
                ACCEPTANCE='; '.join(t['acceptance']) or 'see plan', CONTEXT=', '.join(t['context']) or 'see plan',
                DEPS_DONE=', '.join(dd), PREVIOUS=previous)


def run_task(tid):
    t = S['tasks'][tid]; previous = ''; peer_done = A.no_peer_review
    while True:
        t['attempts'] += 1; key = f'{tid.lower()}-a{t["attempts"]}'; save()
        m = laguna(key, task_prompt(t, previous))
        if m.get('status') == 'ctx_limit' and t['conts'] < 2:
            t['conts'] += 1; t['attempts'] -= 1
            previous = ('\nCONTINUATION: a previous session on this task ran out of its context budget before finishing. Your files '
                        'already contain its work (inspect with `git diff HEAD -- <your files>`). Finish the task; read less this time.')
            continue
        ok, g = gate(key, t['files'], t['tests'])
        if ok and not peer_done:
            peer_done = True
            r = laguna(f'{tid.lower()}-peer', fill(open(f'{TPL}/review_laguna.md').read(), TID=tid, TITLE=t['title'],
                       ACCEPTANCE='; '.join(t['acceptance']), WPLOW=t['wp'].lower(), FILES=', '.join(t['files']), BASE='HEAD'), 'ro')
            res = r.get('result') or ''
            if re.search(r'VERDICT:\s*ISSUES', res) and t['attempts'] < A.max_attempts:
                previous = '\nA reviewer found issues in your finished work; fix them (CHECKLIST each):\n' + res.split('ISSUES', 1)[-1].strip()[:2500]
                continue
        if ok:
            t['status'] = 'done'; t['result'] = (m.get('result') or '')[-1500:]; save(); commit(tid, t['title'], t['files'])
            log(f'DONE {tid} after {t["attempts"]} attempt(s)'); return
        if t['attempts'] < A.max_attempts:
            previous = (f'\nRETRY (attempt {t["attempts"] + 1}): your files already contain the previous attempt. The harness gate '
                        f'FAILED:\n{g[-3000:]}\nPrevious attempt\'s final message:\n{(m.get("result") or "(none)")[-1200:]}\n'
                        'Fix the failures (CHECKLIST each gate failure).')
            continue
        if t.get('da_consults', 0) >= 1:
            t['status'] = 'failed'; t['notes'] += ' | still failing after DA guidance'; save()
            commit(tid, t['title'] + ' (gate failing)', t['files']); log(f'FAILED {tid} (after DA retry)'); return
        t['da_consults'] = t.get('da_consults', 0) + 1
        v, _ = da('task_stuck', TID=tid, TITLE=t['title'], ATTEMPTS=t['attempts'], GATE=g[-2500:], RESPONSE=(m.get('result') or '')[-1500:])
        act = (v or {}).get('action', 'accept')
        if act == 'escalate':
            o, _ = opus('escalation', TID=tid, DETAIL=(v or {}).get('guidance', '')); v = {'action': 'retry', 'guidance': (o or {}).get('decision', '')}
            act = 'retry'
        if act == 'retry':
            previous = f'\nRETRY with guidance from the delivery lead:\n{v.get("guidance", "")}\nLast gate output:\n{g[-2000:]}'
            continue
        if act == 'split' and (v or {}).get('new_tasks'):
            with LOCK:
                for i, nt in enumerate(v['new_tasks']):
                    nid = f'{tid}-S{i + 1}'
                    S['tasks'][nid] = {'id': nid, 'wp': t['wp'], 'title': nt.get('title', ''), 'files': nt.get('files') or t['files'],
                                       'tests': nt.get('tests') or t['tests'], 'deps': [d for d in t['deps']] + ([f'{tid}-S{i}'] if i else []),
                                       'acceptance': nt.get('acceptance') or [], 'context': nt.get('context') or [], 'exclusive': t['exclusive'],
                                       'status': 'todo', 'attempts': 0, 'conts': 0, 'notes': f'split from {tid}'}
                last = f'{tid}-S{len(v["new_tasks"])}'
                for x in S['tasks'].values():
                    if tid in x['deps']:
                        x['deps'] = [last if d == tid else d for d in x['deps']]
                t['status'] = 'split'; save()
            log(f'SPLIT {tid} into {len(v["new_tasks"])}'); return
        t['status'] = 'failed'; t['notes'] = f'DA: {act}: {(v or {}).get("guidance", "")[:300]}'; save()
        commit(tid, t['title'] + ' (gate failing)', t['files']); log(f'FAILED {tid} ({act})'); return


def overlaps(a, b):
    return bool(set(a['files']) & set(b['files']))


def phase_dev():
    for t in S['tasks'].values():
        if t['status'] == 'running':
            t['status'] = 'todo'
    S.setdefault('reviewed', []); save()
    pool = ThreadPoolExecutor(A.slots); running = {}; paused_for = None
    da_pool = ThreadPoolExecutor(1); pending_ms = {}
    while True:
        T = S['tasks']
        for tid in [k for k, f in running.items() if f.done()]:
            exc = running.pop(tid).exception()
            if exc:
                log(f'ERROR {tid}: {exc!r}'); T[tid]['status'] = 'failed'; save()
        # milestone: every task of a package finished -> pause dispatch, run full gate, DA review in background
        for w in S['wps']:
            wid = w['id']; mine = [x for x in T.values() if x['wp'] == wid]
            if mine and wid not in S['milestones'] and all(x['status'] in ('done', 'failed', 'split') for x in mine):
                if running:
                    paused_for = wid; break
                paused_for = None; commit_all(f'{wid} milestone')
                ok, g = milestone(wid.lower()); S['milestones'][wid] = {'gate': 'PASS' if ok else 'FAIL'}; save()
                log(f'MILESTONE {wid}: gate {"PASS" if ok else "FAIL"}')
                if not ok and sum(1 for k in T if k.startswith(f'{wid}-G')) < 2:
                    add_fix(wid, 'G', ['The package milestone gate failed (full suite / mypy / ruff / web). Fix these:\n' + g[-3000:]], mine)
                files = sorted({f for x in mine for f in x['files']})
                if wid in S['reviewed']:
                    continue
                S['reviewed'].append(wid); save()
                pending_ms[wid] = da_pool.submit(da, 'wp_milestone', WPID=wid, WPLOW=wid.lower(), TASKS=', '.join(x['id'] for x in mine),
                                                 GATE=g[-2000:], FILES=' '.join(files))
        for wid, f in list(pending_ms.items()):
            if f.done():
                pending_ms.pop(wid); v, _ = f.result()
                if v and v.get('verdict') == 'REVISE' and v.get('findings'):
                    add_fix(wid, 'R', v['findings'], [x for x in T.values() if x['wp'] == wid])
        hard = elapsed_min() > A.hard_cap_min - 20
        if not hard and paused_for is None:
            for tid, t in sorted(T.items()):
                if len(running) >= A.slots:
                    break
                if t['status'] != 'todo' or tid in running:
                    continue
                if any(T[d]['status'] not in ('done', 'failed', 'split') for d in t['deps'] if d in T):
                    continue
                cur = [T[r] for r in running]
                if any(c['exclusive'] for c in cur) or (t['exclusive'] and cur):
                    continue
                if any(overlaps(t, c) for c in cur):
                    continue
                t['status'] = 'running'; save(); running[tid] = pool.submit(run_task, tid)
        if not running and not pending_ms and (hard or not [t for t in T.values() if t['status'] == 'todo']):
            # all milestones taken?
            if hard or all(w['id'] in S['milestones'] for w in S['wps'] if any(x['wp'] == w['id'] for x in T.values())):
                break
        if elapsed_min() > A.target_min and not S.get('target_logged'):
            S['target_logged'] = True; save(); log(f'TARGET {A.target_min} min passed; tasks done {sum(t["status"] == "done" for t in T.values())}/{len(T)}')
        time.sleep(5)
    S['phase'] = 'final'; save()


def add_fix(wid, kind, findings, mine):
    with LOCK:
        n = sum(1 for k in S['tasks'] if k.startswith(f'{wid}-{kind}')) + 1; fid = f'{wid}-{kind}{n}'
        files = sorted({f for x in mine for f in x['files']}); tests = sorted({f for x in mine for f in x['tests']})
        S['tasks'][fid] = {'id': fid, 'wp': wid, 'title': f'fix {wid} {"gate failures" if kind == "G" else "review findings"}',
                           'files': files, 'tests': tests, 'deps': [], 'acceptance': [f'#{i + 1} {f}' for i, f in enumerate(findings)],
                           'context': [], 'exclusive': True, 'status': 'todo', 'attempts': 0, 'conts': 0, 'notes': 'fix'}
        S['milestones'].pop(wid, None) if kind == 'G' else None   # re-gate the package after a gate fix
        save()
    log(f'FIX task {fid}: {len(findings)} item(s)')


# ---------------- Phase 4: final gate + acceptance ----------------
def phase_final():
    commit_all('final'); ok, g = milestone('final'); log(f'FINAL gate {"PASS" if ok else "FAIL"}')
    st = f'{sum(t["status"] == "done" for t in S["tasks"].values())}/{len(S["tasks"])} tasks done, {elapsed_min():.0f} min'
    v, _ = opus('acceptance', STATUS=st, LEDGER=f'{RD}/ledger.md', GATE=g[-2500:])
    S['phase'] = 'done'; S['verdict'] = (v or {}).get('verdict'); S['t_end'] = time.time(); save()
    log(f'ACCEPTANCE: {S["verdict"]}; Claude ${claude_cost():.2f}; wall {elapsed_min():.0f} min')


if __name__ == '__main__':
    log(f'f2x start rid={A.rid} slots={A.slots} phase={S["phase"]}')
    if S['phase'] == 'goal':
        phase_goal()
    if S['phase'] == 'plans':
        phase_plans()
    if S['phase'] == 'dev':
        phase_dev()
    if S['phase'] == 'final':
        phase_final()
