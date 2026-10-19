# collect_metrics.py — per-run metrics table → results/runs.csv + results/runs.md (all scored runs under runs/)
import json, glob, os, re, csv
B = os.path.expanduser("~/laguna-bench"); rows = []
key = {l.split("\t")[1]: l.split("\t")[0] for l in open(f"{B}/results/review_key.tsv")} if os.path.exists(f"{B}/results/review_key.tsv") else {}
rev = json.load(open(f"{B}/results/review/scores.json")) if os.path.exists(f"{B}/results/review/scores.json") else {}
ARM = {"A": "Sonnet 5.5", "B": "Laguna S 2.1", "H": "Haiku 4.5", "S": "Laguna solo", "X": "Laguna XS 2.1", "Q": "Qwen3.6-35B-A3B", "N": "Laguna S NVFP4 (1 GPU)", "D": "Devstral Small 2", "P": "Nemotron Puzzle 75B"}
for d in sorted(glob.glob(f"{B}/runs/T*-*")):
    r = os.path.basename(d); t = r.split("-")[0]; a = ARM.get(r.split("-")[1][0], "?")
    ms = json.load(open(f"{d}/master.summary.json")) if os.path.exists(f"{d}/master.summary.json") else {}
    summ = open(f"{d}/score/summary.txt").read() if os.path.exists(f"{d}/score/summary.txt") else ""
    res = (re.findall(r"RESULT: (\w+)", summ) or ["DISQ/GATE" if "NOT GREEN" in summ or "DISQUALIFIED" in summ else "-"])[-1]
    hv = re.search(r"hidden\+visible: (.*?) in ", summ); hv = hv.group(1) if hv else ("gate: " + (re.search(r"(\d+ failed, \d+ passed)", summ).group(1) if re.search(r"(\d+ failed, \d+ passed)", summ) else ""))
    ex = [json.load(open(f)) for f in sorted(glob.glob(f"{d}/exec/[0-9]*.json"))]
    eo = sum((e.get("usage") or {}).get("output_tokens", 0) or 0 for e in ex)
    ei = sum(((e.get("usage") or {}).get(k, 0) or 0) for e in ex for k in ("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"))
    m = json.load(open(f"{d}/master.json")) if os.path.exists(f"{d}/master.json") else {}
    mo = sum(v.get("outputTokens", 0) for v in (m.get("modelUsage") or {}).values())
    orders = sorted(glob.glob(f"{d}/orders/order-*.md"), key=lambda p: int(re.findall(r"\d+", os.path.basename(p))[0]))
    fw = sum(len(open(o).read().split()) for o in orders[1:])
    rv = (rev.get(t, {}).get(key.get(r, ""), {}) or {}).get("overall", "")
    rows.append(dict(run=r, task=t, executor=a, result=res, hidden=hv, wall_min=round(ms.get("wall_s", 0) / 60), timed_out=ms.get("timed_out", ""),
                     exec_rounds=len(orders), followup_words=fw, exec_out_tok=eo, exec_in_tok=ei, opus_out_tok=mo, review_overall=rv))
with open(f"{B}/results/runs.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)
with open(f"{B}/results/runs.md", "w") as f:
    f.write("| " + " | ".join(rows[0]) + " |\n|" + "---|" * len(rows[0]) + "\n")
    for x in rows: f.write("| " + " | ".join(str(v) for v in x.values()) + " |\n")
print(open(f"{B}/results/runs.md").read())
