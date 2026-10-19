"""laguna-bench Anthropic-format shim (127.0.0.1:4000 -> vLLM /v1/messages via the SSH tunnel on :18000).

Why: Claude Code puts `role: "system"` messages INSIDE the conversation (environment block, per-turn
`<total_tokens>` reminders). vLLM's Anthropic->chat conversion folds them into the top system prompt, so the
prompt head changes on every request and the prefix cache misses after ~1.2k tokens (measured: ~4% hit rate
in live Claude Code sessions vs ~100% on identical replays). The shim rewrites each in-conversation system
message into an in-place user message wrapped in <system-reminder> tags (content preserved, position preserved),
which keeps the prompt prefix stable. Everything else (tools, thinking + signatures, streaming) passes through
untouched. It also logs client-observed latency per request (TTFT = first streamed byte) to logs/shim.jsonl.

Run: litellm-venv/bin/python bin/shim.py  (uses starlette/uvicorn/httpx from that venv)
"""
import asyncio, json, os, time, itertools
import httpx, uvicorn
from starlette.applications import Starlette
from starlette.responses import StreamingResponse, Response, JSONResponse
from starlette.routing import Route

UPSTREAM = os.environ.get("SHIM_UPSTREAM", "http://127.0.0.1:18000")
LOG = os.path.expanduser("~/laguna-bench/logs/shim.jsonl")
client = httpx.AsyncClient(timeout=httpx.Timeout(1800.0, connect=10.0), limits=httpx.Limits(max_connections=200))
seq = itertools.count(1)
# SHIM_SERIAL=1 (Anand 2026-10-16: "one agent at a time, but pick up the next immediately"): at most ONE /v1/messages
# request is in flight upstream; others queue here (FIFO) and start the moment the current stream ends. Both agents keep
# their KV resident in llama.cpp (-np 2 --kv-unified), so a switch costs no re-prefill, and decode is never concurrent
# (concurrent decode costs DFlash ~40% on rewrites).
SERIAL = asyncio.Semaphore(1) if os.environ.get("SHIM_SERIAL") == "1" else None


def rewrite(body: dict) -> int:
    n = 0
    out = []
    for m in body.get("messages", []):
        if m.get("role") == "system":
            c = m.get("content")
            text = c if isinstance(c, str) else "\n".join(b.get("text", "") for b in (c or []) if isinstance(b, dict))
            out.append({"role": "user", "content": [{"type": "text", "text": f"<system-reminder>\n{text}\n</system-reminder>"}]})
            n += 1
        else:
            out.append(m)
    body["messages"] = out
    return n


# llama.cpp builds a tool-call grammar from each tool's input_schema; Poolside's llama.cpp fork (needed for DFlash) fails on
# Claude Code's schemas ("number of repetitions exceeds sane defaults" from huge maxLength/maxItems, "unsupported pattern
# syntax" from regex patterns) and answers HTTP 400 — F2-1 never got past its first turn (2026-10-16). Drop ONLY those
# constraint keywords; names, types, descriptions, required fields are untouched. GATEWAY DEVIATION, SHIM_SANITIZE=0 disables.
_DROP = ("pattern", "format")
_CAP = {"maxLength": 1000, "minLength": 1000, "maxItems": 100, "minItems": 100, "maxProperties": 100}


def _clean(node) -> int:
    n = 0
    if isinstance(node, dict):
        for k in _DROP:
            if k in node and isinstance(node[k], str):
                del node[k]; n += 1
        for k, cap in _CAP.items():
            if isinstance(node.get(k), int) and node[k] > cap:
                del node[k]; n += 1
        for v in node.values():
            n += _clean(v)
    elif isinstance(node, list):
        for v in node:
            n += _clean(v)
    return n


def sanitize_tools(body: dict) -> int:
    if os.environ.get("SHIM_SANITIZE", "1") != "1":
        return 0
    return sum(_clean(t.get("input_schema")) for t in body.get("tools", []) or [] if isinstance(t, dict))


def log(rec: dict) -> None:
    with open(LOG, "a") as f:
        f.write(json.dumps(rec) + "\n")


async def messages(request):
    raw = await request.body()
    rid = next(seq)
    sanitized = None
    thinking_in = None
    try:
        body = json.loads(raw)
        moved = rewrite(body)
        # SHIM_THINK_BUDGET=N (F2-4, 2026-10-17): Claude Code sends no thinking budget for a non-Anthropic model, so llama.cpp
        # thinks unbounded (single passes of ~19k tokens). Force {"type":"enabled","budget_tokens":N}; the Poolside server maps it
        # to its reasoning budget. Unset = pass through. thinking_in records what the client sent.
        thinking_in = body.get("thinking")
        tb = int(os.environ.get("SHIM_THINK_BUDGET", "0") or 0)
        try:   # live override without restart: echo N > logs/think_budget  (0 = pass through)
            tb = int(open(os.path.expanduser("~/laguna-bench/logs/think_budget")).read().strip() or tb)
        except (OSError, ValueError):
            pass
        if tb > 0:
            body["thinking"] = {"type": "enabled", "budget_tokens": tb}
        # SHIM_EXTRA_BODY='<json object>' (2026-10-19, OpenRouter tests): shallow-merge extra top-level fields into every
        # /v1/messages request, e.g. '{"provider":{"quantizations":["bf16"],"allow_fallbacks":false}}' to pin OpenRouter
        # routing to full-precision providers. Unset = no change.
        extra = os.environ.get("SHIM_EXTRA_BODY")
        if extra:
            body.update(json.loads(extra))
        sanitized = sanitize_tools(body)
        if os.environ.get('SHIM_DUMP'):
            open(os.path.expanduser(f'~/laguna-bench/scratch/cap/shim{rid:04d}.json'),'w').write(json.dumps({k:v for k,v in body.items() if k!='messages' and k!='tools' and k!='system'}))
        raw = json.dumps(body).encode()
    except Exception:
        moved = -1
    hdrs = {k: v for k, v in request.headers.items() if k.lower() in ("content-type", "anthropic-version", "anthropic-beta", "x-api-key", "authorization")}
    hdrs["accept-encoding"] = "identity"   # we stream raw upstream bytes; a gzip'd body without its content-encoding header breaks clients (OpenRouter compresses)
    tq = time.time()
    held = False
    if SERIAL is not None:   # bounded wait: a leaked permit (client gone before streaming) must never deadlock the bench
        try:
            await asyncio.wait_for(SERIAL.acquire(), timeout=900)
            held = True
        except asyncio.TimeoutError:
            log({"id": rid, "t": time.time(), "queue_timeout": True})
    t0 = time.time()
    queued = round(t0 - tq, 3)
    up = None
    for attempt in range(3):   # stale pooled keep-alive connections fail before the request is processed → safe to resend
        try:
            req = client.build_request("POST", UPSTREAM + request.url.path, content=raw, headers=hdrs, params=request.query_params)
            up = await client.send(req, stream=True)
            break
        except (httpx.RemoteProtocolError, httpx.ConnectError, httpx.ReadError) as e:
            log({"id": rid, "t": time.time(), "retry": attempt + 1, "error_retried": repr(e)})
            if attempt == 2:
                up = e
    try:
        if isinstance(up, Exception):
            raise up
    except httpx.HTTPError as e:
        log({"id": rid, "t": t0, "error": repr(e), "path": request.url.path})
        if held:
            SERIAL.release()
        return JSONResponse({"type": "error", "error": {"type": "api_error", "message": f"shim upstream error: {e!r}"}}, status_code=529)

    async def gen():
        first = None
        size = 0
        try:
            async for chunk in up.aiter_raw():
                if first is None:
                    first = time.time()
                size += len(chunk)
                yield chunk
        finally:
            await up.aclose()
            if held:
                SERIAL.release()
            log({"id": rid, "t": t0, "status": up.status_code, "ttft_s": round((first or time.time()) - t0, 3),
                 "total_s": round(time.time() - t0, 3), "queued_s": queued, "resp_bytes": size, "req_bytes": len(raw),
                 "sys_moved": moved, "schema_fixes": sanitized, "thinking_in": thinking_in, "model": body.get("model") if isinstance(body, dict) else None})

    return StreamingResponse(gen(), status_code=up.status_code,
                             headers={k: v for k, v in up.headers.items() if k.lower() in ("content-type", "cache-control")})


async def passthrough(request):
    raw = await request.body()
    r = await client.request(request.method, UPSTREAM + request.url.path, content=raw,
                             headers={k: v for k, v in request.headers.items() if k.lower() in ("content-type", "anthropic-version")})
    return Response(r.content, status_code=r.status_code, headers={"content-type": r.headers.get("content-type", "application/json")})


app = Starlette(routes=[
    Route("/v1/messages", messages, methods=["POST"]),
    Route("/v1/messages/count_tokens", passthrough, methods=["POST"]),
    Route("/{path:path}", passthrough, methods=["GET", "POST", "HEAD"]),
])

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=int(os.environ.get("SHIM_PORT", "4000")), log_level="warning")
