import asyncio
import json
import time
from datetime import datetime, timezone
from aiohttp import web


def _pick_client_ip(request: web.Request) -> str:
    xff = request.headers.get("X-Forwarded-For", "").strip()
    if xff:
        return xff.split(",", 1)[0].strip()
    xrip = request.headers.get("X-Real-IP", "").strip()
    if xrip:
        return xrip
    if request.remote:
        return request.remote
    return "unknown"


async def tarpit_handler(request: web.Request) -> web.StreamResponse:
    started = time.monotonic()
    client_ip = _pick_client_ip(request)
    host = request.headers.get("Host", "")
    ua = request.headers.get("User-Agent", "")

    response = web.StreamResponse(
        status=200,
        reason="OK",
        headers={
            "Content-Type": "text/plain; charset=utf-8",
            "Cache-Control": "no-cache, no-store, must-revalidate",
        },
    )
    await response.prepare(request)

    chunks_sent = 0
    disconnected = False

    # Hold unauthorized scanner sockets for ~5 minutes.
    for _ in range(30):
        try:
            await response.write(b" ")
            chunks_sent += 1
            await asyncio.sleep(10)
        except (ConnectionResetError, asyncio.CancelledError, RuntimeError):
            disconnected = True
            break

    event = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "event": "tarpit_request",
        "client_ip": client_ip,
        "host": host,
        "method": request.method,
        "path": request.path_qs,
        "user_agent": ua,
        "chunks_sent": chunks_sent,
        "hold_seconds": round(time.monotonic() - started, 3),
        "disconnected_early": disconnected,
    }
    print(json.dumps(event, ensure_ascii=True), flush=True)

    return response


app = web.Application()
app.router.add_route("*", "/{tail:.*}", tarpit_handler)


if __name__ == "__main__":
    web.run_app(app, host="127.0.0.1", port=9090)
