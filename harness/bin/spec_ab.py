#!/usr/bin/env python3
"""laguna-bench — speculative-decoding speed A/B (runs ON the box against 127.0.0.1:8000, OpenAI-compatible API).
Two workloads: 'gen' (write new code) and 'edit' (return a stdlib file with type hints added = Edit/Write-like output),
each at concurrency 1 and 2; streaming, so TTFT and post-first-token decode speed are separated.
Usage: spec_ab.py <label> <served_model> [max_tokens=1024] [long]  -> appends JSON lines to /opt/bench/spec_ab.jsonl"""
import json, sys, time, threading, urllib.request
label, model = sys.argv[1], sys.argv[2]; MT = int(sys.argv[3]) if len(sys.argv) > 3 else 1024
src = open('/usr/lib/python3.12/json/decoder.py').read()
LONG = len(sys.argv) > 4 and sys.argv[4] == 'long'   # agent-sized context: ~60k tokens of stdlib source in front of the task
ctx = ''
if LONG:
    import glob
    for f in sorted(glob.glob('/usr/lib/python3.12/asyncio/*.py')) + sorted(glob.glob('/usr/lib/python3.12/email/*.py')):
        if len(ctx) > 230000: break
        ctx += '\n# ==== FILE ' + f + '\n' + open(f).read()
PROMPTS = {
  'gen': 'Write a complete Python module implementing an LRU cache with TTL expiry, thread safety, and a decorator form, plus pytest tests. Output only code.',
  'edit': 'Add full type hints to this module. Keep everything else byte-identical. Output the whole file only.\n\n' + src,
}
def one(prompt, out):
    body = json.dumps({'model': model, 'stream': True, 'stream_options': {'include_usage': True}, 'max_tokens': MT, 'temperature': 1.0, 'top_k': 20,
                       'messages': [{'role': 'user', 'content': prompt}]}).encode()
    req = urllib.request.Request('http://127.0.0.1:8000/v1/chat/completions', body, {'content-type': 'application/json'})
    t0 = time.time(); t1 = None; n = 0; toks = None
    with urllib.request.urlopen(req, timeout=900) as r:
        for line in r:
            if not line.startswith(b'data: ') or line.strip() == b'data: [DONE]': continue
            d = json.loads(line[6:]); u = d.get('usage') or {}
            if u.get('completion_tokens'): toks = u['completion_tokens']
            ch = (d.get('choices') or [{}])[0].get('delta', {})
            if ch.get('content') or ch.get('reasoning_content') or ch.get('reasoning'):
                n += 1; t1 = t1 or time.time()
    t2 = time.time(); out.append({'ttft': round((t1 or t2) - t0, 2), 'chunks': n, 'tokens': toks or n, 'decode_s': round(t2 - (t1 or t2), 2)})
if LONG:
    PROMPTS = {'gen': ctx + '\n\nUsing the code above as context: ' + PROMPTS['gen'],
               'edit': ctx + '\n\nAdd full type hints to json/decoder.py below, keep everything else byte-identical, output the whole file only.\n\n' + src}
    label += '-long'
for wl, p in PROMPTS.items():
    for c in [int(v) for v in __import__('os').environ.get('CONC', '1,2').split(',')]:
        for rep in range(2):
            res = []; th = [threading.Thread(target=one, args=(p, res)) for _ in range(c)]
            T0 = time.time(); [t.start() for t in th]; [t.join() for t in th]; wall = time.time() - T0
            rec = {'label': label, 'workload': wl, 'conc': c, 'rep': rep, 'wall_s': round(wall, 1),
                   'per_stream_tok_per_s': [round(x['tokens'] / x['decode_s'], 1) if x['decode_s'] else None for x in res],
                   'agg_tok_per_s': round(sum(x['tokens'] for x in res) / wall, 1), 'ttft': [x['ttft'] for x in res]}
            print(json.dumps(rec), flush=True); open('/opt/bench/spec_ab.jsonl', 'a').write(json.dumps(rec) + '\n')
