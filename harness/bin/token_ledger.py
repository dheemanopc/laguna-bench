#!/usr/bin/env python3
"""laguna-bench — token ledger per run, per role, per model (Anand 2026-10-16: 'keep track of tokens consumed, for each type of task').
Reads every Claude Code transcript whose cwd is under runs/<run_id>* (executor, master, owner, DA, verifier, acceptance sessions),
de-duplicates streamed chunks by message id, classifies the session's role from its first prompt, and sums
input / cache-read / cache-write / output tokens. Local-model (Laguna etc.) usage is what the llama.cpp/vLLM server reported.
Usage: token_ledger.py <run_id_prefix>...   (e.g. F2-1  T4)  -> prints a table; --json for machine output.
Appends nothing; safe to re-run at any time (also mid-run)."""
import json, glob, os, sys, collections
B = os.path.expanduser('~/laguna-bench'); P = os.path.expanduser('~/.claude/projects')
# classified on the OPENING of the session's first prompt (orders mention 'acceptance' etc. in their body)
ROLES = [('you are the product owner', 'owner'), ('you are the design authority', 'design-lead'),
         ('you are the lead engineer (planner/reviewer)', 'master'), ('you are the tech lead. developers have implemented', 'verify-plan'),
         ('you are the tech lead. independent verifiers', 'verify-decision'), ('you are an independent verification', 'verifier'),
         ('you are the engineer responsible for this task end to end', 'solo-dev'), ('you are the acceptance', 'acceptance'),
         ('you are the reviewer', 'acceptance')]
def role_of(first):
    h = first.strip().lower()[:200]
    for k, r in ROLES:
        if h.startswith(k): return r
    return 'dev-order' if h.startswith('#') else 'other:' + h[:40].replace('\n', ' ')
def ledger(prefix):
    tot = collections.defaultdict(lambda: collections.Counter())
    for d in glob.glob(f"{P}/-home-anand-laguna-bench-runs-{prefix}*") + glob.glob(f"{P}/-home-anand-laguna-bench-verify-{prefix}*"):
        for f in glob.glob(f"{d}/*.jsonl"):
            seen = {}; first = None
            for l in open(f, errors='replace'):
                try: x = json.loads(l)
                except Exception: continue
                m = x.get('message') or {}
                if first is None and m.get('role') == 'user':
                    c = m.get('content'); first = c if isinstance(c, str) else ' '.join(i.get('text', '') for i in c if isinstance(i, dict))
                if m.get('role') == 'assistant' and m.get('usage'):
                    seen[m.get('id') or x.get('uuid')] = (m.get('model'), m['usage'])   # last chunk of a message carries final usage
            r = role_of(first or '')
            for model, u in seen.values():
                if model == '<synthetic>': continue
                c = tot[(r, model)]; c['msgs'] += 1
                for k, n in (('input_tokens', 'in'), ('cache_read_input_tokens', 'cache_read'), ('cache_creation_input_tokens', 'cache_write'), ('output_tokens', 'out')):
                    c[n] += u.get(k) or 0
            for k in list(tot):
                pass
    return tot
if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    out = {}
    for p in args:
        t = ledger(p)
        out[p] = {f'{r}|{m}': dict(c) for (r, m), c in sorted(t.items())}
        if '--json' not in sys.argv:
            print(f'== {p}'); print(f"{'role':16} {'model':22} {'msgs':>6} {'input':>11} {'cache_read':>12} {'cache_write':>11} {'output':>9}")
            for (r, m), c in sorted(t.items()):
                print(f"{r:16} {m:22} {c['msgs']:6} {c['in']:11,} {c['cache_read']:12,} {c['cache_write']:11,} {c['out']:9,}")
    if '--json' in sys.argv: print(json.dumps(out, indent=1))
