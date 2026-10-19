# live_stats.py [minutes=60] — real agent-traffic throughput on the instance from /opt/bench/metrics.csv
import csv, sys, collections, datetime as d
M = int(sys.argv[1]) if len(sys.argv) > 1 else 60
R = list(csv.DictReader(open("/opt/bench/metrics.csv")))
t = lambda r: d.datetime.strptime(r["ts"], "%Y-%m-%dT%H:%M:%SZ")
end = t(R[-1]); W = [r for r in R if (end - t(r)).total_seconds() <= M * 60]
a, b = W[0], W[-1]; dt = (t(b) - t(a)).total_seconds(); f = lambda k: float(b[k]) - float(a[k])
gen, pr, hits, q = f("gen_tokens"), f("prompt_tokens"), f("prefix_hits"), f("prefix_queries")
run = [float(r["running"]) for r in W]; kv = [float(r["kv_usage"]) for r in W]
print("window %s -> %s (%.0f min)" % (a["ts"], b["ts"], dt / 60))
print("generation %.0f tok/s | prompt processed %.0f tok/s | prefix-cache hits %.1f%% of %.1fM prompt tokens | uncached prefill %.0f tok/s" % (gen / dt, pr / dt, hits / q * 100, q / 1e6, (pr - hits) / dt))
print("running seqs avg %.2f (min %d max %d) | KV avg %.0f%% | server mean TTFT %.2fs over %d requests" % (sum(run) / len(run), min(run), max(run), sum(kv) / len(kv) * 100, f("ttft_sum") / max(f("ttft_count"), 1), f("ttft_count")))
h = collections.Counter(int(x) for x in run); print("time share by #running:", {k: "%.0f%%" % (v / len(run) * 100) for k, v in sorted(h.items())})
