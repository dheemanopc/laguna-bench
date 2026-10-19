# Prefix-repeat test: identical ~300k-token prefix sent twice (different short suffix); cold vs warm TTFT.
import json, time, urllib.request, random
U = "http://127.0.0.1:8000"
words = "alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau".split()
random.seed(int(time.time()))
def ntok(text):
    b = json.dumps({"model": "laguna-s-2.1", "prompt": text}).encode()
    return json.load(urllib.request.urlopen(urllib.request.Request(U + "/tokenize", data=b, headers={"content-type": "application/json"})))["count"]
base = " ".join(random.choice(words) for _ in range(10000)); per = ntok(base) / 10000
prefix = " ".join(random.choice(words) for _ in range(int(298000 / per)))
def ttft(suffix):
    body = json.dumps({"model": "laguna-s-2.1", "max_tokens": 16, "stream": True, "stream_options": {"include_usage": True},
                       "chat_template_kwargs": {"enable_thinking": False},
                       "messages": [{"role": "user", "content": prefix + "\n" + suffix}]}).encode()
    req = urllib.request.Request(U + "/v1/chat/completions", data=body, headers={"content-type": "application/json"})
    t0 = time.time(); first = None; pt = None
    for line in urllib.request.urlopen(req, timeout=1800):
        if first is None and line.startswith(b"data:") and b'"content"' in line: first = time.time() - t0
        if b'"prompt_tokens"' in line: pt = json.loads(line[5:])["usage"]["prompt_tokens"]
    return first, pt
c, pt = ttft("Question one: count the word alpha. Answer briefly.")
w, _ = ttft("Question two: is beta present? Answer briefly.")
print(json.dumps({"prefix_test": {"prompt_tokens": pt, "cold_ttft_s": round(c, 2), "warm_ttft_s": round(w, 2)}}))
