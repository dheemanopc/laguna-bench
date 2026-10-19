#!/usr/bin/env python3
"""replay.py <run_id> <TID>... — replay F2-4 tasks on a hosted model (2026-10-17, Anand: "Sonnet can plan. But I need a
faithful model for impl"; "use its full intelligence"). Same task template, rules, per-task gate and fresh test DBs as f2x;
the model runs remotely (OpenRouter). Tasks run in order on runs/<run_id>/repo (each builds on the previous commit).
Per task: up to 3 attempts with the gate output fed back (as f2x), commit on PASS. Faithfulness record per attempt:
  claims_pass  = the model's TESTS line says passed and nothing failed      gate_pass = harness gate PASS
  out_of_scope = changed paths outside the task's files                       red_flags = gate RED FLAG present
Cost = OpenRouter key usage delta (USD). Results -> runs/<run_id>/replay.jsonl
Env: LAGUNA_BASE_URL, LAGUNA_KEY_FILE, LAGUNA_MODEL (passed through to laguna_task.sh)."""
import json, os, re, subprocess, sys, time, urllib.request

B = os.path.expanduser('~/laguna-bench'); RID = sys.argv[1]; TIDS = sys.argv[2:]
RD = f'{B}/runs/{RID}'; REPO = f'{RD}/repo'; TPL = f'{B}/templates'
S = json.load(open(f'{B}/runs/F2-4/state.json')); T = S['tasks']
RULES = open(f'{TPL}/rules.md').read(); MAXA = 3
os.makedirs(f'{RD}/prompts', exist_ok=True)


def usage():
    kf = os.environ.get('LAGUNA_KEY_FILE')
    if not kf:
        return 0.0
    req = urllib.request.Request('https://openrouter.ai/api/v1/key', headers={'Authorization': 'Bearer ' + open(kf).read().strip()})
    try:
        return float(json.load(urllib.request.urlopen(req, timeout=20))['data']['usage'])
    except Exception:
        return float('nan')


def fill(t, **kw):
    for k, v in kw.items():
        t = t.replace('{' + k + '}', str(v))
    return t


def prompt(t, previous=''):
    dd = [f'{d} ({T[d]["title"]})' for d in t['deps'] if d in T and T[d]['wp'] == t['wp']] or ['none']
    return fill(open(f'{TPL}/task.md').read(), RULES=RULES, WPLOW=t['wp'].lower(), TID=t['id'], TITLE=t['title'],
                FILES=', '.join(t['files']) or '(decide; keep it small)', TESTS=', '.join(t['tests']) or 'none',
                ACCEPTANCE='; '.join(t['acceptance']) or 'see plan', CONTEXT=', '.join(t['context']) or 'see plan',
                DEPS_DONE=', '.join(dd), PREVIOUS=previous)


def sh(*a):
    return subprocess.run(list(a), cwd=REPO, capture_output=True, text=True)


def changed():
    out = sh('git', 'status', '--porcelain').stdout.splitlines()
    return [l[3:].strip() for l in out if not l[3:].startswith('docs/feature')]


for tid in TIDS:
    t = T[tid]; previous = ''
    for a in range(1, MAXA + 1):
        key = f'{tid.lower()}-a{a}'; pf = f'{RD}/prompts/{key}.md'; open(pf, 'w').write(prompt(t, previous))
        u0 = usage(); t0 = time.time()
        r = subprocess.run([f'{B}/bin/laguna_task.sh', RID, key, pf, 'rw'], capture_output=True, text=True)
        m = json.loads(r.stdout[r.stdout.find('{'):]) if '{' in r.stdout else {}
        g = subprocess.run([f'{B}/bin/task_gate.sh', RID, key, ','.join(t['files']), ','.join(t['tests'])], capture_output=True, text=True)
        gate = g.stdout; open(f'{RD}/t/{key}.gate.md', 'w').write(gate)
        res = m.get('result') or ''
        mt = re.search(r'TESTS:(.*?)(?:\n(?:CHECKLIST|NOTES|CHANGED|RESULT):|\Z)', res, re.S)
        tests_line = mt.group(1) if mt else ''
        claims_pass = bool(re.search(r'\bpassed\b', tests_line)) and not re.search(r'\b[1-9]\d* (failed|errors?)\b', tests_line)
        scope = [p for p in changed() if p not in t['files']]
        rec = {'task': tid, 'attempt': a, 'status': m.get('status'), 'wall_s': round(time.time() - t0), 'ctx_max': m.get('ctx_max'),
               'compactions': m.get('compactions'), 'gate_pass': 'RESULT: PASS' in gate, 'claims_pass': claims_pass,
               'claim_mismatch': claims_pass and 'RESULT: PASS' not in gate, 'out_of_scope': scope,
               'red_flags': 'RED FLAG' in gate, 'cost_usd': round(usage() - u0, 4), 'result_head': res[:300]}
        open(f'{RD}/replay.jsonl', 'a').write(json.dumps(rec) + '\n'); print(json.dumps(rec), flush=True)
        if rec['gate_pass']:
            sh('git', 'add', '--', *[f for f in t['files'] if os.path.exists(f'{REPO}/{f}')])
            sh('git', 'commit', '-q', '-m', f'{tid}: {t["title"]} (replay {RID})', '--', *t['files'])
            break
        previous = (f'\nRETRY (attempt {a + 1}): your files already contain the previous attempt. The harness gate FAILED:\n'
                    f'{gate[-3000:]}\nPrevious attempt\'s final message:\n{res[-1200:]}\n')
    else:
        print(json.dumps({'task': tid, 'final': 'FAILED'}), flush=True); break
