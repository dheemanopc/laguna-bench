# exp_evict.py <n_sessions> <tokens_each> — "parked agent" test for KV offload (runs ON the instance).
# Sends n distinct prompts of ~tokens_each (each = one agent context), enough in total to overflow GPU KV,
# then revisits session #1 with a new suffix. With CPU offload, #1's prefix should come back from RAM
# (low TTFT); without, it is re-prefilled cold. Prints cold TTFT of #1, revisit TTFT of #1, and the
# prefix-cache / offload counters.
import json, sys, time, random, urllib.request
U = "http://127.0.0.1:8000"; n = int(sys.argv[1]); L = int(sys.argv[2])
W = "alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau".split()
def post(path, body):
    return urllib.request.urlopen(urllib.request.Request(U + path, data=json.dumps(body).encode(), headers={"content-type": "application/json"}), timeout=3600)
def ntok(t): return json.load(post("/tokenize", {"model": "laguna-s-2.1", "prompt": t}))["count"]
per = ntok(" ".join(random.choice(W) for _ in range(5000))) / 5000
def ctx(seed):
    r = random.Random(seed); return " ".join(r.choice(W) for _ in range(int(L / per)))
def ttft(text):
    t0 = time.time()
    for line in post("/v1/chat/completions", {"model": "laguna-s-2.1", "max_tokens": 4, "stream": True,
            "chat_template_kwargs": {"enable_thinking": False}, "messages": [{"role": "user", "content": text}]}):
        if line.startswith(b"data:") and b'"content"' in line: return round(time.time() - t0, 2)
    return round(time.time() - t0, 2)
def metrics():
    m = urllib.request.urlopen(U + "/metrics").read().decode()
    return {k: sum(float(l.split()[-1]) for l in m.splitlines() if l.startswith(k)) for k in
            ("vllm:prefix_cache_hits_total", "vllm:prefix_cache_queries_total", "vllm:external_prefix_cache_hits_total", "vllm:external_prefix_cache_queries_total")}
seed0 = int(time.time()); res = {"n": n, "tokens_each": L}
res["s1_cold_ttft_s"] = ttft(ctx(seed0) + "\nQ1: say ok")
res["s1_warm_ttft_s"] = ttft(ctx(seed0) + "\nQ1b: say ok")
fill = [ttft(ctx(seed0 + i) + "\nQ: say ok") for i in range(1, n)]
res["fill_ttft_s_mean"] = round(sum(fill) / len(fill), 2)
m0 = metrics(); res["s1_revisit_ttft_s"] = ttft(ctx(seed0) + "\nQ2: say ok"); m1 = metrics()
res["revisit_counters_delta"] = {k: m1[k] - m0[k] for k in m0}
print(json.dumps(res))
