#!/usr/bin/env python3
"""laguna-bench — tokens AND cost per stage for a run (Anand 2026-10-16: "I really want to measure cost of opus tokens", per task).
Claude tokens come from the session transcripts (usage per message, de-duplicated by message id), priced at Anthropic
first-party API rates (claude-api skill, cached 2026-09-25). The sessions themselves run on the Claude Code login, so this is
the API-EQUIVALENT price, not what the subscription bills. Local-model (Laguna) tokens are free per token; their cost is
the GPU box's wall time per stage at the spot price (the whole box is attributed to the run).
Stages come from 'stage <name> start' / 'review <stage> ...' / 'acceptance' markers in runs/<id>/master.started.
Usage: cost_report.py <run_id> [--gpu-usd-hr 3.4373] [--json]"""
import json, glob, os, sys, re, collections, datetime as dt

B = os.path.expanduser('~/laguna-bench'); P = os.path.expanduser('~/.claude/projects')
# $ per million tokens: input, output, cache read, cache write 5m, cache write 1h
PRICE = {'claude-opus-5-5': (4.0, 20.0, 0.20, 5.0, 8.0), 'claude-sonnet-5-5': (2.0, 10.0, 0.20, 2.5, 4.0),
         'claude-haiku-4-5': (1.0, 5.0, 0.10, 1.25, 2.0)}


def ts(s):
    return dt.datetime.fromisoformat(s.replace('Z', '+00:00')).timestamp()


def stage_windows(rid):
    ev = []
    for l in open(f'{B}/runs/{rid}/master.started'):
        m = re.match(r'(\S+) (.*)', l.strip())
        if m:
            ev.append((ts(m.group(1)), m.group(2)))
    wins = []   # (start, name) for 'stage X start' markers
    for t, e in ev:
        m = re.match(r'stage (\S+) start', e)
        if m:
            wins.append((t, m.group(1)))
    end = os.path.getmtime(f'{B}/runs/{rid}/master.summary.json') if os.path.exists(f'{B}/runs/{rid}/master.summary.json') else dt.datetime.now().timestamp()
    out = []
    for i, (t, n) in enumerate(wins):
        out.append((n, t, wins[i + 1][0] if i + 1 < len(wins) else end))
    return out or [('run', ev[0][0] if ev else 0, end)]


def stage_of(t, wins):
    for n, a, b in wins:
        if a <= t < b:
            return n
    return wins[-1][0] if t >= wins[-1][2] else wins[0][0]


def main():
    rid = sys.argv[1]; gpu = float(sys.argv[sys.argv.index('--gpu-usd-hr') + 1]) if '--gpu-usd-hr' in sys.argv else 3.4373
    wins = stage_windows(rid)
    tok = collections.defaultdict(collections.Counter)   # (stage, role, model) -> counters
    for d in glob.glob(f'{P}/-home-anand-laguna-bench-runs-{rid}*'):
        for f in glob.glob(f'{d}/*.jsonl'):
            first, msgs = None, {}
            for l in open(f, errors='replace'):
                try:
                    x = json.loads(l)
                except Exception:
                    continue
                m = x.get('message') or {}
                if first is None and m.get('role') == 'user':
                    c = m.get('content'); first = c if isinstance(c, str) else ' '.join(i.get('text', '') for i in c if isinstance(i, dict))
                if m.get('role') == 'assistant' and m.get('usage') and m.get('model') != '<synthetic>':
                    msgs[m.get('id') or x.get('uuid')] = (x.get('timestamp'), m.get('model'), m['usage'])
            h = (first or '').strip()
            mstage = re.search(r'This is the (\S+) gate', h)
            role = ('architect' if h.startswith('You are the ARCHITECT') else 'acceptance' if 'final ACCEPTANCE' in h[:120]
                    else 'engineer')
            for t, model, u in msgs.values():
                st = mstage.group(1) if mstage else ('acceptance' if role == 'acceptance' else stage_of(ts(t), wins))
                c = tok[(st, role, model)]
                c['msgs'] += 1; c['in'] += u.get('input_tokens') or 0; c['out'] += u.get('output_tokens') or 0
                c['cr'] += u.get('cache_read_input_tokens') or 0
                cc = u.get('cache_creation') or {}
                w1h = cc.get('ephemeral_1h_input_tokens') or 0; w5m = cc.get('ephemeral_5m_input_tokens')
                if w5m is None:
                    w5m = (u.get('cache_creation_input_tokens') or 0) - w1h
                c['w5m'] += w5m; c['w1h'] += w1h
    rows, tot = [], collections.Counter()
    order = [w[0] for w in wins] + ['acceptance']
    for (st, role, model), c in sorted(tok.items(), key=lambda k: (order.index(k[0][0]) if k[0][0] in order else 99, k[0][1])):
        p = PRICE.get(model)
        usd = sum(c[k] * p[i] for k, i in (('in', 0), ('out', 1), ('cr', 2), ('w5m', 3), ('w1h', 4))) / 1e6 if p else 0.0
        rows.append(dict(stage=st, role=role, model=model, usd=round(usd, 4), **c)); tot['claude_usd'] += usd
    gpu_rows = [dict(stage=n, minutes=round((b - a) / 60, 1), gpu_usd=round((b - a) / 3600 * gpu, 3)) for n, a, b in wins]
    tot['gpu_usd'] = sum(r['gpu_usd'] for r in gpu_rows)
    if '--json' in sys.argv:
        print(json.dumps({'rows': rows, 'gpu': gpu_rows, 'total': dict(tot)}, indent=1)); return
    print(f"== {rid}  (Claude priced at first-party API rates; GPU at ${gpu}/hr spot)")
    print(f"{'stage':12} {'role':11} {'model':20} {'msgs':>5} {'input':>9} {'cache_rd':>11} {'wr5m':>8} {'wr1h':>9} {'output':>8} {'$':>8}")
    for r in rows:
        print(f"{r['stage']:12} {r['role']:11} {r['model']:20} {r['msgs']:5} {r['in']:9,} {r['cr']:11,} {r['w5m']:8,} {r['w1h']:9,} {r['out']:8,} {r['usd']:8.3f}")
    print('-- GPU time per stage: ' + ', '.join(f"{g['stage']} {g['minutes']}m ${g['gpu_usd']}" for g in gpu_rows))
    print(f"-- TOTAL: Claude ${tot['claude_usd']:.3f} (API-equivalent) + GPU ${tot['gpu_usd']:.2f} = ${tot['claude_usd'] + tot['gpu_usd']:.2f}")


main()
